##################################################
package Log::Log4perl::Appender::ScreenColoredLevels;
##################################################
our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;

use Term::ANSIColor qw();
use Log::Log4perl::Level;

##################################################
sub new {
##################################################
    my($class, %options) = @_;

    my $self = {
        name     => "unknown name",
        stderr   => 1,
        color    => {},
        appender => undef,
        %options,
    };

    if($self->{appender}) {
          # Pass back the appender to be limited as a dependency
          # to the configuration file parser
        push @{$options{l4p_depends_on}}, $self->{appender};

          # Run our post_init method in the configurator after
          # all appenders have been defined to make sure the
          # appenders we're connecting to really exist.
        push @{$options{l4p_post_config_subs}}, sub { $self->post_init() };
    }

      # also accept lower/mixed case levels in config
    for my $level ( keys %{ $self->{color} } ) {
        my $uclevel = uc($level);
        $self->{color}->{$uclevel} = $self->{color}->{$level};
    }

    my %default_colors = (
        TRACE   => 'yellow',
        DEBUG   => '',
        INFO    => 'green',
        WARN    => 'blue',
        ERROR   => 'magenta',
        FATAL   => 'red',
    );
    for my $level ( keys %default_colors ) {
        if ( ! exists $self->{ 'color' }->{ $level } ) {
            $self->{ 'color' }->{ $level } = $default_colors{ $level };
        }
    }

    bless $self, $class;
}
    
##################################################
sub log {
##################################################
    my($self, %params) = @_;

    my $string_or_array = $params{ 'message' };

      # We might be called as a composite appender, in which case we
      # get a ref to an array of message snippets instead of a readily
      # warped message
    my @msgs = ($string_or_array);
    if(ref $string_or_array eq "ARRAY") {
        @msgs = @$string_or_array;
    }

    for my $snip (@msgs) {
        if ( my $color = $self->{ 'color' }->{ $params{ 'log4p_level' } } ) {
          $snip = Term::ANSIColor::colored( $snip, $color );
        }
    }
    
    if($self->{app}) {
        # It's used as a composite appender, forward formatted message
        # to real appender
        $params{message} = \@msgs;
        $self->{app}->SUPER::log(\%params,
                                 $params{log4p_category},
                                 $params{log4p_level});
    } elsif($self->{stderr}) {
        print STDERR $msgs[0];
    } else {
        print $msgs[0];
    }
}

###########################################
sub post_init {
###########################################
    my($self) = @_;

    if(! exists $self->{appender}) {
        # No appender defined, not in composite mode
        return 1;
    }

    my $appenders = Log::Log4perl->appenders();
    my $appender = Log::Log4perl->appenders()->{$self->{appender}};

    if(! defined $appender) {
       die "Appender $self->{appender} not defined (yet) when " .
           __PACKAGE__ . " needed it";
    }

    $self->{app} = $appender;
}

1;

__END__

=head1 NAME

Log::Log4perl::Appender::ScreenColoredLevel - Colorize messages according to level

=head1 SYNOPSIS

    use Log::Log4perl qw(:easy);

    Log::Log4perl->init(\ <<'EOT');
      log4perl.category = DEBUG, Screen
      log4perl.appender.Screen = \
          Log::Log4perl::Appender::ScreenColoredLevels
      log4perl.appender.Screen.layout = \
          Log::Log4perl::Layout::PatternLayout
      log4perl.appender.Screen.layout.ConversionPattern = \
          %d %F{1} %L> %m %n
    EOT

      # Appears black
    DEBUG "Debug Message";

      # Appears green
    INFO  "Info Message";

      # Appears blue
    WARN  "Warn Message";

      # Appears magenta
    ERROR "Error Message";

      # Appears red
    FATAL "Fatal Message";

=head1 DESCRIPTION

This appender acts like Log::Log4perl::Appender::Screen, except that
it colorizes its output, based on the priority of the message sent.

You can configure the colors and attributes used for the different
levels, by specifying them in your configuration:

    log4perl.appender.Screen.color.TRACE=cyan
    log4perl.appender.Screen.color.DEBUG=bold blue

You can also specify nothing, to indicate that level should not have
coloring applied, which means the text will be whatever the default
color for your terminal is.  This is the default for debug messages.

    log4perl.appender.Screen.color.DEBUG=

You can use any attribute supported by L<Term::ANSIColor> as a configuration
option.

    log4perl.appender.Screen.color.FATAL=\
        bold underline blink red on_white

The commonly used colors and attributes are:

=over 4

=item attributes

BOLD, DARK, UNDERLINE, UNDERSCORE, BLINK

=item colors

BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE

=item background colors

ON_BLACK, ON_RED, ON_GREEN, ON_YELLOW, ON_BLUE, ON_MAGENTA, ON_CYAN, ON_WHITE

=back

See L<Term::ANSIColor> for a complete list, and information on which are
supported by various common terminal emulators.

The default values for these options are:

=over 4

=item Trace

Yellow

=item Debug

None (whatever the terminal default is)

=item Info

Green

=item Warn

Blue

=item Error

Magenta

=item Fatal

Red

=back

The constructor C<new()> takes an optional parameter C<stderr>,
if set to a true value, the appender will log to STDERR. If C<stderr>
is set to a false value, it will log to STDOUT. The default setting
for C<stderr> is 1, so messages will be logged to STDERR by default.
The constructor can also take an optional parameter C<color>, whose
value is a  hashref of color configuration options, any levels that
are not included in the hashref will be set to their default values.

=head2 Using ScreenColoredLevels in composite mode

ScreenColoredLevels can be used as a preprocessor for other appenders,
responsible for coloring text before it gets logged by other appenders.

To enable this mode, define the other appender B<first>, so that
ScreenColoredLevels can reference its name in its I<appender> attribute:

        # Define the final appender first
      log4perl.appender.File = Log::Log4perl::Appender::File
      log4perl.appender.File.filename = test.log
      log4perl.appender.File.layout = \
          Log::Log4perl::Layout::SimpleLayout

        # Now define ScreenColoredLevels appender referencing
        # the final appender.
      log4perl.appender.Colors = \
          Log::Log4perl::Appender::ScreenColoredLevels
      log4perl.appender.Colors.appender = File

=head1 AUTHOR

Mike Schilli C<< <log4perl@perlmeister.com> >>, 2004

Color configuration and attribute support added 2007 by
Jason Kohles C<< <email@jasonkohles.com> >>.

=cut
