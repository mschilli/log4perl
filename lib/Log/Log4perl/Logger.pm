##################################################
package Log::Log4perl::Logger;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Layout;
use Log::Dispatch;

    # Initialization
our $ROOT_LOGGER;
our $LOGGERS_BY_STRING;
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
    our $ROOT_LOGGER          = __PACKAGE__->_new("", $DEBUG);
    our $LOGGERS_BY_STRING    = {};
}

##################################################
sub _new {
##################################################
    my($class, $logger_class, $level) = @_;

    die "usage: __PACKAGE__->new(logger_class)" unless
        defined $logger_class;
    
    $logger_class  =~ s/::/./g;

       # Have we created it previously?
    if(exists $LOGGERS_BY_STRING->{$logger_class}) {
        return $LOGGERS_BY_STRING->{$logger_class};
    }

    my $self  = {
        logger_class => $logger_class,
        appenders    => 0,
        additivity   => 1,
        level        => $level,
        dispatcher   => Log::Dispatch->new(),
        layout       => undef,
                };

        # Save it in global structure
    $LOGGERS_BY_STRING->{$logger_class} = $self;

    bless $self, $class;

    return $self;
}


##################################################
sub layout {
##################################################
    my($self, $format_string) = @_;

    $self->{layout} = Log::Log4perl::Layout->new();
    $self->{layout}->define($format_string);
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
        $self->{level} = $level;   #need to do validation here !!!
        $self->{level_str} = Log::Log4perl::Level::to_string($level);
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
            
        if(defined $LOGGERS_BY_STRING->{$logger->{logger_class}}->{level}) {
            return $LOGGERS_BY_STRING->{$logger->{logger_class}}->{level};
        }
    }

    # We should never get here because at least the root logger should
    # have a level defined
    die "We should never get here.";
}

##################################################
sub level_str {
##################################################
    my($self, $level_str) = @_;

        # 'Set' function
    if($level_str) {
        $self->{level_str} = $level_str;  #need to do validation here !!!
        $self->{level} = Log::Log4perl::Level::to_level($level_str);
        return $level_str;
    }

        # 'Get' function
    if($self->{level_str}) {
        return $self->{level_str};
        #maybe it hasn't been set yet, so do it, this is a kludge
    }elsif(defined $self->{level}){
        $self->{level_str} = Log::Log4perl::Level::to_string($self->{level});;
    }

    for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

        # Does the current logger have the level defined?

        if($logger->{logger_class} eq "") {
            # It's the root logger
            return $ROOT_LOGGER->{level_str};
        }
            
        if(defined $LOGGERS_BY_STRING->{$logger->{logger_class}}->{level_str}) {
            return $LOGGERS_BY_STRING->{$logger->{logger_class}}->{level_str};
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
          ! exists $LOGGERS_BY_STRING->{$parent_class}) {
        $parent_class = parent_string($parent_class);
        $logger =  $LOGGERS_BY_STRING->{$parent_class};
    }

    if($parent_class eq "") {
        $logger = $ROOT_LOGGER;
    } else {
        $logger = $LOGGERS_BY_STRING->{$parent_class};
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
    my($self, $appender) = @_;

    $self->{appenders}++;
    $self->{dispatcher}->add($appender);
}

##################################################
sub has_appenders {
##################################################
    my($self) = @_;

    return $self->{appenders};
}

##################################################
sub log {
##################################################
    my($self, $level, @message) = @_;

    my $message = join '', @message;

    if($level <= $self->level()) {
        # Call the dispatchers up the hierarchy
        for(my $logger = $self; $logger; $logger = parent_logger($logger)) {

               # Only format the message if there's going to be an appender.
            next unless $logger->has_appenders();

                # If we have a layout, use it.
            if($logger->{layout}) {
                $message = $logger->{layout}->render($logger, $message, 2);
            }
                # Dispatch the (formatted) message
            $logger->{dispatcher}->log(
                level   => lc(Log::Log4perl::Level::to_string($level)),
                message => $message);
            last unless $logger->{additivity};
        }
    }
}

##################################################
sub debug { &log($_[0], $DEBUG, @_[1,]); }
sub info  { &log($_[0], $INFO,  @_[1,]); }
sub warn  { &log($_[0], $WARN,  @_[1,]); }
sub error { &log($_[0], $ERROR, @_[1,]); }
sub fatal { &log($_[0], $FATAL, @_[1,]); }
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

Why not use a debugger? Kernighan said it 

I like the concepts behind C<log4perl>. I loathe the name, 
though. It sounds to me like B2B and Ejb and all these other useless
Sun products. But, hey, the name stands for the concept, so I kept it.

=head2 Levels

FATAL, ERROR, WARN, INFO and DEBUG

=head2 Configuration files

=head2 Appenders

=head2 Layout patterns

=head2 How to log

    use Log::Log4perl;

    our $Logger = Log::Log4perl->getInstance();

Why not C<Log::Log4perl-E<gt>new()>? We don't want to create a new
object every time. Usually in OO-Programming, you create an object
once and use the reference to it to call its methods. However,
this requires that you pass around the object to all functions
and the last thing we want is pollute each and every function/method
we're using with a handle to the Logger:

    sub function {
        my($logger, $some, $other, $parameters) = @_;
    }

Instead, if a function/method wants a reference to the logger, it
just calls the Logger's static C<getInstance()> method to obtain
a reference to the I<one and only> possible logger object.
That's called a I<singleton> if you're a Gamma fan.

=head2 How to log in an object

    package MyPackage;

    use Log::Log4perl;

    our $Logger = Log::Log4perl->getInstance();

    sub new { ... }

    sub method {
        ...
        $Logger->info("Doing well ...");
    }

=head2 Reconfigure at runtime

Signal?

=head2 Penalties

Logging comes with a price tag.

    $Logger->info("...") if $Logger->is_info();

Or, if you can save serious time because what you're logging is

        # Expensive in non-debug mode!
    for (@super_long_array) {
        $Logger->debug("Element: $_\n");
    }

        # Cheap in non-debug mode!
    if($Logger->is_debug()) {
        for (@super_long_array) {
            $Logger->debug("Element: $_\n");
        }
    }

=head2 EXPORT

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=head1 INSTALL

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

=head1 How about Log::Dispatch::Config?

Yeah, I've seen it. I like it, but I think it is too dependent
on defining everything in a configuration file.
I've designed C<Log::Log4perl> to be more flexible.

=head1 References

=over 4

=item [1]

Vipan Singla, "Don't Use System.out.println! Use Log4j.",
http://www.vipan.com/htdocs/log4jhelp.html

=item [2]


=back

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
