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
use Carp;

    # Initialization
our $ROOT_LOGGER;
our $LOGGERS_BY_NAME;
our %LAYOUT_BY_APPENDER;
our %APPENDER_BY_NAME = ();
our $DISPATCHER = Log::Dispatch->new();

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
    our $ROOT_LOGGER        = __PACKAGE__->_new("", $DEBUG);
    our $DISPATCHER         = Log::Dispatch->new();
    our $LOGGERS_BY_NAME    = {};
    our %APPENDER_BY_NAME   = ();
}

##################################################
sub _new {
##################################################
    my($class, $category, $level) = @_;

    die "usage: __PACKAGE__->_new(category)" unless
        defined $category;
    
    $category  =~ s/::/./g;

       # Have we created it previously?
    if(exists $LOGGERS_BY_NAME->{$category}) {
        return $LOGGERS_BY_NAME->{$category};
    }

    my $self  = {
        logger_class  => $category,
        num_appenders => 0,
        additivity    => 1,
        level         => $level,
        dispatcher    => $DISPATCHER,
        layout        => undef,
                };

        # Save it in global structure
    $LOGGERS_BY_NAME->{$category} = $self;

    bless $self, $class;

    return $self;
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
    my($self, $level) = @_;

        # 'Set' function
    if(defined $level) {
        croak "invalid level '$level'" 
                unless Log::Log4perl::Level::is_valid($level);
        $self->{level} = $level;   
        return $level;
    }

        # 'Get' function
    if(defined $self->{level}) {
        return $self->{level};
    }

    for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

        # Does the current logger have the level defined?

        if($logger->{logger_class} eq "") {
            # It's the root logger
            return $ROOT_LOGGER->{level};
        }
            
        if(defined $LOGGERS_BY_NAME->{$logger->{logger_class}}->{level}) {
            return $LOGGERS_BY_NAME->{$logger->{logger_class}}->{level};
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
    if($logger->{logger_class} eq "") {
        # Root has no parent
        return undef;
    }

        # Go to the next defined (!) parent
    my $parent_class = parent_string($logger->{logger_class});

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
    my($class, $logger_class) = @_;

    unless(defined $ROOT_LOGGER) {
        die "Logger not initialized. No previous call to init()?";
    }

    return $ROOT_LOGGER if $logger_class eq "";

    my $logger = $class->_new($logger_class);
    return $logger;
}

##################################################
sub add_appender {
##################################################
    my($self, $appender, $not_to_dispatcher) = @_;

    my $appender_name = $appender->name();

    $self->{num_appenders}++;

    unless (grep{$_ eq $appender_name} @{$self->{appender_names}}){
        $self->{appender_names} = [sort @{$self->{appender_names}}, 
                                        $appender_name];
    }

    #ugly, but while we want to track the names of
    #all the appenders in a category, we only
    #want to add it to log_dispatch *once*
    $self->{dispatcher}->add($appender)
        unless $APPENDER_BY_NAME{$appender_name};

    $APPENDER_BY_NAME{$appender_name} = $appender;
}

##################################################
sub has_appenders {
##################################################
    my($self) = @_;

    return $self->{num_appenders};
}

##################################################
sub log {
##################################################
    my($self, $level, $priority, @message) = @_;

    my %seen;

    my $message = join '', @message;

    my $category = $self->{logger_class};

    if($priority <= $self->level()) {
        # Call the dispatchers up the hierarchy
        for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

               # Only format the message if there's going to be an appender.
            next unless $logger->has_appenders();

            foreach my $appender_name (@{$logger->{appender_names}}){

                    #only one message per appender, please
                next if $seen{$appender_name} ++;

                my $appender = $APPENDER_BY_NAME{$appender_name};

                my $rendered_msg;

                if ($appender->layout()) {
                    $rendered_msg = $appender->layout()->render(
                            $logger, $message, $category,
                            $level, 2);  # 2 levels up from the renderer
                                         # is the function 
                                         # calling into the Logger
                }else{
                    # Accoding to 
                    # http://jakarta.apache.org/log4j/docs/api/org/...
                    # apache/log4j/SimpleLayout.html this is the default layout
                    # TODO: Replace with SimpleFormat
                    $rendered_msg = "$level - $message";
                }

                    # Dispatch the (formatted) message
                $logger->{dispatcher}->log_to(
                    name    => $appender_name,
                    level   => lc(Log::Log4perl::Level::to_string($priority)),
                    message => $rendered_msg,
                    );
            }
            last unless $logger->{additivity};
        }
    }
}

##################################################
sub debug { &log($_[0], 'DEBUG', $DEBUG, @_[1,]); }
sub info  { &log($_[0], 'INFO',  $INFO,  @_[1,]); }
sub warn  { &log($_[0], 'WARN',  $WARN,  @_[1,]); }
sub error { &log($_[0], 'ERROR', $ERROR, @_[1,]); }
sub fatal { &log($_[0], 'FATAL', $FATAL, @_[1,]); }

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

      # Init it only once
  Log::Log4perl::Logger->init();

      # Obtain an instance of a logger (many times)
      # (_new() is not used externally because of singleton
      #  behaviour)
  my $logger = Log::Log4perl::Logger->get_logger($component);

      # Add an appender to the logger
  Log::Log4perl::Logger->add_appender($appender);

      # re-init to delete all previously defined loggers
  Log::Log4perl::Logger->reset();

      # Log if logger's level is $level or higher
  Log::Log4perl::Logger->log($level, $message);

      # Log if logger's level is DEBUG or higher
  Log::Log4perl::Logger->debug($message);
      # Log if logger's level is DEBUG or higher
  Log::Log4perl::Logger->info($message);
      # Log if logger's level is DEBUG or higher
  Log::Log4perl::Logger->warn($message);
      # Log if logger's level is DEBUG or higher
  Log::Log4perl::Logger->error($message);
      # Log if logger's level is DEBUG or higher
  Log::Log4perl::Logger->fatal($message);

      # True if logger's level is DEBUG or higher
  Log::Log4perl::Logger->is_debug();
      # True if logger's level is INFO or higher
  Log::Log4perl::Logger->is_info();
      # True if logger's level is WARN or higher
  Log::Log4perl::Logger->is_warn();
      # True if logger's level is ERROR or higher
  Log::Log4perl::Logger->is_error();
      # True if logger's level is FATAL
  Log::Log4perl::Logger->is_fatal();

=head1 DESCRIPTION

C<Log::Log4perl::Logger> is the main logger class. It provides the
method C<get_logger($compontent)> which obtains a 
logger. This is different from I<creating> a logger because
loggers are only created once and then this single one instance is
used all over the system. For this reason, there's no C<new()>
method (there's an internal-only method called C<_new()> just in
case you're curious).

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
