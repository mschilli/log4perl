##################################################
package Log::Log4perl::Appender;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use constant DEBUG => 0;

our $unique_counter = 0;

##################################################
sub reset {
##################################################
    $unique_counter = 0;
}

##################################################
sub unique_name {
##################################################
        # THREADS: Need to lock here to make it thread safe
    $unique_counter++;
    my $unique_name = sprintf("app%03d", $unique_counter);
        # THREADS: Need to unlock here to make it thread safe
    return $unique_name;
}

##################################################
sub new {
##################################################
    my($class, $appenderclass, %params) = @_;

        # Pull in the specified Log::Log4perl::Appender object
    eval {
        # see 'perldoc -f require' for why two evals
        eval "require $appenderclass";  
        die $@ if $@;
    };

    $@ and die "ERROR: appenderclass $appenderclass doesn't exist\n";

    $params{name} = unique_name() unless exists $params{name};

    my $appender = $appenderclass->new(
            # Set min_level to default, *we* are controlling this now
        min_level => 'debug', 
            # Set 'name' and other parameters
        map { $_ => $params{$_} } keys %params,
    );

    my $self = {
                 appender => $appender,
                 name     => $params{name},
                 layout   => undef,
                 level    => $DEBUG,
               };
    
    bless $self, $class;

    return $self;
}

##################################################
sub threshold { # Set/Get the appender threshold
##################################################
    my ($self, $level) = @_;

    print "Setting threshold to $level\n" if DEBUG;

    if(defined $level) {
        $self->{level} = $level;
    }

    return $self->{level};
}

##################################################
sub log { # Relay this call to Log::Dispatch::Whatever
##################################################
    my ($self, $p, $category, $level) = @_;

    # Check if the appender has a last-minute veto in form
    # of an "appender threshold"
    if($self->{level} > $
                        Log::Log4perl::Level::PRIORITY{$level}) {
      print "$self->{level} > $level, aborting\n" if DEBUG;
        return;
    }

    $self->{layout} || $self->layout();  #set to default if not already
                                         #can this be moved?

    #doing the rendering in here 'cause this is 
    #where we keep the layout
    $p->{message} = $self->{layout}->render($p->{message}, 
                                            $category,
                                            $level,
                                            3 + $Log::Log4perl::caller_depth,
                                            );
    return $self->{appender}->log(%$p);
}

##################################################
sub name { # Set/Get the name
##################################################
    my($self, $name) = @_;

        # Somebody wants to *set* the name?
    if($name) {
        $self->{name} = $name;
    }

    return $self->{name};
}

###########################################
sub layout { # Set/Get the layout object
             # associated with this appender
###########################################
    my($self, $layout) = @_;

        # Somebody wants to *set* the layout?
    if($layout) {
        $self->{layout} = $layout;

        # somebody wants a layout, but not set yet, so give 'em default
    }elsif (! $self->{layout}) {
        $self->{layout} = Log::Log4perl::Layout::SimpleLayout
                                                ->new($self->{name})

    }

    return $self->{layout};
}

##################################################
sub AUTOLOAD { # Relay everything else to the underlying Log::Dispatch object
##################################################
    my $self = shift;

    no strict qw(vars);

    $AUTOLOAD =~ s/.*:://;

    return $self->{appender}->$AUTOLOAD(@_);
}

##################################################
sub DESTROY {
##################################################
    # just there because of AUTOLOAD
}

1;

__END__

=head1 NAME

Log::Log4perl::Appender - Log appender class

=head1 SYNOPSIS

  use Log::Log4perl;

      # Define a logger
  my $logger = Log::Log4perl->get_logger("abc.def.ghi");

      # Define a layout
  my $layout = Log::Log4perl::Layout::PatternLayout->new(
                   "%d (%F:%L)> %m");

      # Define an appender
  my $appender = Log::Log4perl::Appender->new(
                   "Log::Dispatch::Screen",
                   name => 'dumpy');

      # Set the appender's layout
  $appender->layout($layout);
  $logger->add_appender($appender);

=head1 DESCRIPTION

This class is a wrapper around the C<Log::Dispatch::*> collection of
dispatchers, so they can be used by C<Log::Log4perl>. 
The module hides the idiosyncrasies of C<Log::Dispatch>
(e.g. every dispatcher gotta have a name, but there's no accessor to retrieve it)
from C<Log::Log4perl> and yet re-uses the extremely useful 
variety of dispatchers already created and tested
in C<Log::Dispatch>.

=head1 FUNCTIONS

=head2 Log::Dispatch::Appender->new($dispatcher_class_name, ...);

The constructor C<new()> takes the name of the C<Log::Dispatcher>
class to be created as a I<string> (!) argument, optionally followed by 
a number of C<Log::Dispatcher::Whatever>-specific parameters,
for example:

      # Define an appender
  my $appender = Log::Log4perl::Appender->new("Log::Dispatch::File"
                                              name => 'dumpy',
                                              file => 'out.log');

If no C<name> parameter is specified, the appender object will create
a unique one (format C<appNNN>), which can be retrieved later via
the C<name()> method:

  print "The appender's name is ", $appender->name(), "\n";

Other parameters are specific to the C<Log::Dispatch> module being used.
In the case above, the C<file> parameter specifies the name of 
the C<Log::Dispatch::File> dispatcher used. 

However, if you're using a C<Log::Dispatch::Email> dispatcher to send you 
email, you'll have to specify C<from> and C<to> email addresses.
Every dispatcher is different.
Please check the C<Log::Dispatch::*> documentation for the appender used
for details on specific requirements.

The C<new()> method will just pass these parameters on to a newly created
C<Log::Dispatch::*> object of the specified type.

When it comes to logging, the C<Log::Log4perl::Appender> will transparently
relay all messages to the C<Log::Dispatch::*> object it carries 
in its womb.

=head2 $appender->layout($layout);

The C<layout()> method sets the log layout
used by the appender to the format specified by the 
C<Log::Log4perl::Layout::*> object which is passed to it as a reference.
Currently there's two layouts available:

    Log::Log4perl::Layout::SimpleLayout
    Log::Log4perl::Layout::PatternLayout

Please check the L<Log::Log4perl::Layout::SimpleLayout> and 
L<Log::Log4perl::Layout::PatternLayout> manual pages for details.

=head1 Supported Appenders 

Here's the list of appender modules currently available via C<Log::Dispatch>,
if not noted otherwise, written by Dave Rolsky:

       Log::Dispatch::ApacheLog
       Log::Dispatch::DBI (by Tatsuhiko Miyagawa)
       Log::Dispatch::Email,
       Log::Dispatch::Email::MailSend,
       Log::Dispatch::Email::MailSendmail,
       Log::Dispatch::Email::MIMELite
       Log::Dispatch::File
       Log::Dispatch::Handle
       Log::Dispatch::Screen
       Log::Dispatch::Syslog
       Log::Dispatch::Tk (by Dominique Dumont)

C<Log4perl> doesn't care which ones you use, they're all handled in 
the same way via the C<Log::Log4perl::Appender> interface.
Please check the well-written manual pages of the 
C<Log::Dispatch> hierarchy on how to use each one of them.

=head1 SEE ALSO

Log::Dispatch

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>

=cut
