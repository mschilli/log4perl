##################################################
package Log::Log4perl::Logger;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Layout;
use Log::Log4perl::Appender;
use Log::Dispatch;
use Data::Dumper;
use Carp;

use constant DEBUG => 0;

    # Initialization
our $ROOT_LOGGER;
our $LOGGERS_BY_NAME;
our %APPENDER_BY_NAME = ();

our $DISPATCHER = Log::Dispatch->new();

our $WATCH_DELAY;
our $FILE_TO_WATCH;
our $LAST_CHECKED_AT;
our $LAST_CHANGED_AT;

__PACKAGE__->reset();

##################################################
sub init {
##################################################
    my($class) = @_;

    return $ROOT_LOGGER;
}

##################################################
sub reset {
##################################################
    $ROOT_LOGGER        = __PACKAGE__->_new("", $DEBUG);
    $LOGGERS_BY_NAME    = {};
    %APPENDER_BY_NAME   = ();
    $DISPATCHER         = Log::Dispatch->new();
    Log::Log4perl::Appender::reset();
}

##################################################
sub _new {
##################################################
    my($class, $category, $level) = @_;

    print("_new: $class/$category/", defined $level ? $level : "undef",
          "\n") if DEBUG;

    die "usage: __PACKAGE__->_new(category)" unless
        defined $category;
    
    $category  =~ s/::/./g;

       # Have we created it previously?
    if(exists $LOGGERS_BY_NAME->{$category}) {
        print "_new: exists already\n" if DEBUG;
        return $LOGGERS_BY_NAME->{$category};
    }

    my $self  = {
        category  => $category,
        num_appenders => 0,
        additivity    => 1,
        level         => $level,
        layout        => undef,
                };

   bless $self, $class;

   $level ||= $self->level();

        # Save it in global structure
   $LOGGERS_BY_NAME->{$category} = $self;

   $self->set_output_methods;

   return $self;
}

##################################################
sub reset_all_output_methods {
##################################################
    print "reset_all_output_methods: \n" if DEBUG;

    foreach my $loggername ( keys %$LOGGERS_BY_NAME){
        $LOGGERS_BY_NAME->{$loggername}->set_output_methods;
    }
    $ROOT_LOGGER->set_output_methods;
}

##################################################
sub set_output_methods {
# Here's a big performance increase.  Instead of having the logger
# calculate whether to log and whom to log to every time log() is called,
# we calculcate it once when the logger is created, and recalculate
# it if the config information ever changes.
#
##################################################
   my ($self) = @_;
    
   my (@appenders, %seen);

   my ($level) = $self->level();

   print "set_output_methods: $self->{category}/$level\n" if DEBUG;

   #collect the appenders in effect for this category    

   for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

        foreach my $appender_name (@{$logger->{appender_names}}){

                #only one message per appender, please
            next if $seen{$appender_name} ++;

            push (@appenders,     
                   [$appender_name,
                    $APPENDER_BY_NAME{$appender_name},
                   ]
            );
        }
        last unless $logger->{additivity};
    }

        #make a no-op coderef for inactive levels
    my $noop = generate_noop_coderef();

       #make a coderef
    my $coderef = (! @appenders ? $noop : &generate_coderef(\@appenders)); 

    my %priority = %Log::Log4perl::Level::PRIORITY; #convenience and cvs

    foreach my $levelname (keys %priority){
        if ($priority{$levelname} <= $level) {
            print "  ($priority{$levelname} <= $level)\n"
                  if DEBUG;
            $self->{$levelname} = $coderef;
        }else{
            print "  ($priority{$levelname} > $level)\n" if DEBUG;
            $self->{$levelname} = $noop;
        }

        print("  Setting $self->{category}.$levelname to ",
              ($self->{$levelname} == $noop ? "NOOP" : 
              ("Coderef: " . scalar @appenders . " appenders")), 
              "\n") if DEBUG;
    }
}

##################################################
sub generate_coderef {
##################################################
    my $appenders = shift;
                    
    print "generate_coderef: ", scalar @$appenders, 
          " appenders\n" if DEBUG;

    my $coderef = '';
    my $watch_delay_code = '';

    # Doing this with eval strings to sacrifice init/reload time
    # for runtime efficiency, so the conditional won't be included
    # if it's not needed

    if (defined $WATCH_DELAY) {
        $watch_delay_code = generate_watch_code();
    }

    my $code = <<EOL;
    \$coderef = sub {
      my (\$logger)  = shift;
      my (\$level)   = pop;
      my (\$message) = join '', \@_;
      
      print("coderef: \$logger->{category}\n") if DEBUG;

      $watch_delay_code;  #note interpolation here
      
      foreach my \$a (\@\$appenders) {   #note the closure here
          my (\$appender_name, \$appender) = \@\$a;

          print("  Sending message '\$message' (\$level) " .
                "to \$appender_name\n") if DEBUG;
    
          \$appender->log(
              #these get passed through to Log::Dispatch
              { name    => \$appender_name,
                level   => 0,   
                message => \$message,
              },
              #these we need
              \$logger->{category},
              \$level,
          );
    
      } #end foreach appenders
    
    }; #end coderef

EOL

    eval $code or die "$@";

    return $coderef;
}

##################################################
sub generate_noop_coderef {
##################################################
    my $coderef = '';
    my $watch_delay_code = '';

    if (defined $WATCH_DELAY) {
        $watch_delay_code = generate_watch_code();
        $watch_delay_code = <<EOL;
        my (\$logger)  = shift;
        my (\$level)   = pop;
        my (\$message) = join '', \@_;
        $watch_delay_code
EOL
    }

    my $code = <<EOL;
    \$coderef = sub {
        print("noop: \n") if DEBUG;
        $watch_delay_code
     };
EOL

    eval $code or die "$@";

    return $coderef;
}


##################################################
sub generate_watch_code {
##################################################
    print "generate_watch_code:\n" if DEBUG;

    return <<'EOL';
        print "exe_watch_code:\n" if DEBUG;

        #more closures here
        if ( (($LAST_CHECKED_AT + $WATCH_DELAY) < time())
                &&  ($LAST_CHANGED_AT < (stat($FILE_TO_WATCH))[9] )){
                
            print "  Config file has been modified\n" if DEBUG;

            %APPENDER_BY_NAME = ();
            $DISPATCHER = Log::Dispatch->new();
            
            Log::Log4perl->init_and_watch($FILE_TO_WATCH, $WATCH_DELAY);
            
            my $methodname = lc($level);
            $logger->$methodname($message); # send the message 
                                            # to the new configuration
            
            $LAST_CHECKED_AT = time();
            
            return;
        }else{
            $LAST_CHECKED_AT = time();
        }
EOL
}

##################################################
sub parent_string {
##################################################
    my($string) = @_;

    if($string eq "") {
        return undef; # root doesn't have a parent.
    }

    my @components = split /\./, $string;
    
    if(@components == 1) {
        return "";
    }

    pop @components;

    return join('.', @components);
}

##################################################
sub level {
##################################################
    my($self, $level, $dont_reset_all) = @_;

        # 'Set' function
    if(defined $level) {
        croak "invalid level '$level'" 
                unless Log::Log4perl::Level::is_valid($level);
        $self->{level} = $level;   

        &reset_all_output_methods
            unless $dont_reset_all;  #keep us from getting overworked 
                                     #if it's the config file calling us 

        return $level;
    }

        # 'Get' function
    if(defined $self->{level}) {
        return $self->{level};
    }

    for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

        # Does the current logger have the level defined?

        if($logger->{category} eq "") {
            # It's the root logger
            return $ROOT_LOGGER->{level};
        }
            
        if(defined $LOGGERS_BY_NAME->{$logger->{category}}->{level}) {
            return $LOGGERS_BY_NAME->{$logger->{category}}->{level};
        }
    }

    # We should never get here because at least the root logger should
    # have a level defined
    die "We should never get here.";
}

##################################################
sub parent_logger {
# Get the parent of the current logger or undef
##################################################
    my($logger) = @_;

        # Is it the root logger?
    if($logger->{category} eq "") {
        # Root has no parent
        return undef;
    }

        # Go to the next defined (!) parent
    my $parent_class = parent_string($logger->{category});

    while($parent_class ne "" and
          ! exists $LOGGERS_BY_NAME->{$parent_class}) {
        $parent_class = parent_string($parent_class);
        $logger =  $LOGGERS_BY_NAME->{$parent_class};
    }

    if($parent_class eq "") {
        $logger = $ROOT_LOGGER;
    } else {
        $logger = $LOGGERS_BY_NAME->{$parent_class};
    }

    return $logger;
}

##################################################
sub get_root_logger {
##################################################
    my($class) = @_;
    return $ROOT_LOGGER;    
}

##################################################
sub additivity {
##################################################
    my($self, $onoff) = @_;

    if(defined $onoff) {
        $self->{additivity} = $onoff;
    }

    return $self->{additivity};
}

##################################################
sub get_logger {
##################################################
    my($class, $category) = @_;

    unless(defined $ROOT_LOGGER) {
        die "Logger not initialized. No previous call to init()?";
    }

    return $ROOT_LOGGER if $category eq "";

    my $logger = $class->_new($category);
    return $logger;
}

##################################################
sub add_appender {
##################################################
    my($self, $appender, $dont_reset_all) = @_;

    my $not_to_dispatcher = 0;

    my $appender_name = $appender->name();

    $self->{num_appenders}++;  #should this be inside the unless?

    unless (grep{$_ eq $appender_name} @{$self->{appender_names}}){
        $self->{appender_names} = [sort @{$self->{appender_names}}, 
                                        $appender_name];
    }

    if ($APPENDER_BY_NAME{$appender_name}) {
        $not_to_dispatcher = 1;
    }else{
        $APPENDER_BY_NAME{$appender_name} = $appender;
    }

    &reset_all_output_methods
                unless $dont_reset_all;  # keep us from getting overworked
                                         # if it's  the config file calling us


    #$self->{dispatcher}->add($appender) unless $not_to_dispatcher;    
    $DISPATCHER->add($appender) unless $not_to_dispatcher;    
        # while we want to track the names of
        # all the appenders in a category, we only
        # want to add it to log_dispatch *once*
}

##################################################
sub has_appenders {
##################################################
    my($self) = @_;

    return $self->{num_appenders};
}

##################################################
sub init_watch {
##################################################
    $WATCH_DELAY = shift;

    $LAST_CHECKED_AT = $LAST_CHANGED_AT = time();
}

##################################################
sub set_file_to_watch {
##################################################
    $FILE_TO_WATCH = shift;
}

##################################################
sub log {
# external api
##################################################
    my ($self, $priority, @messages) = @_;

       # Just in case of 'init_and_watch' -- see Changes 0.21
    $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;

    croak "priority $priority isn't numeric" if ($priority =~ /\D/);

    my $which = Log::Log4perl::Level::to_level($priority);

    $self->{$which}($self, @messages, 
                    Log::Log4perl::Level::to_level($priority));
}

##################################################
#expected args are $logger, $msg, $levelname

sub fatal {
   print "fatal: ($_[0]->{category}/$_[0]->{level}) [@_]\n" if DEBUG;
       # Just in case of 'init_and_watch' -- see Changes 0.21
   $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;
   $_[0]->{FATAL}(@_, 'FATAL');
}

sub error {
   print "error: ($_[0]->{category}/$_[0]->{level}) [@_]\n" if DEBUG;
       # Just in case of 'init_and_watch' -- see Changes 0.21
   $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;
   $_[0]->{ERROR}(@_, 'ERROR');
}

sub warn {
   print "warn: ($_[0]->{category}/$_[0]->{level}) [@_]\n" if DEBUG;
       # Just in case of 'init_and_watch' -- see Changes 0.21
   $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;
   $_[0]->{WARN} (@_, 'WARN' );
}

sub info {
   print "info: ($_[0]->{category}/$_[0]->{level}) [@_]\n" if DEBUG;
       # Just in case of 'init_and_watch' -- see Changes 0.21
   $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;
   $_[0]->{INFO} (@_, 'INFO' );
}

sub debug {
   print "debug: ($_[0]->{category}/$_[0]->{level}) [@_]\n" if DEBUG;
       # Just in case of 'init_and_watch'
   $_[0] = $LOGGERS_BY_NAME->{$_[0]->{category}} if defined $LAST_CHECKED_AT;
   $_[0]->{DEBUG}(@_, 'DEBUG');
}

sub is_debug { return $_[0]->level() >= $DEBUG; }
sub is_info  { return $_[0]->level() >= $INFO; }
sub is_warn  { return $_[0]->level() >= $WARN; }
sub is_error { return $_[0]->level() >= $ERROR; }
sub is_fatal { return $_[0]->level() >= $FATAL; }
##################################################

1;

__END__

=head1 NAME

Log::Log4perl::Logger - Main Logger

=head1 SYNOPSIS

  use Log::Log4perl::Logger;

  my $log =  Log::Log4perl::Logger();
  $log->debug("Debug Message");

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
