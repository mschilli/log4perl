##################################################
package Log::Log4perl::Filter;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;

use constant DEBUG => 0;

1;

__END__

=head1 NAME

Log::Log4perl::Filter - Log4perl Custom Filter Base Class

=head1 SYNOPSIS

  use Log::Log4perl;

  Log::Log4perl->init(<<'EOT');
    log4perl.logger = INFO, Screen
    log4perl.filter.MyFilter        = sub { /let this through/ }
    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.Filter = MyFilter
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
  EOT

      # Define a logger
  my $logger = Log::Log4perl->get_logger("Some");

      # Let this through
  $logger->info("Here's the info, let this through!");

      # Suppress this
  $logger->info("Here's the info, suppress this!");

=head1 DESCRIPTION

Log4perl allows the use of customized filters in its appenders
to control the output of messages. These filters might grep for
certain text chunks in a message, verify that its priority
matches or exceeds a certain level or that this is the 10th
time the same message has been submitted -- and come to a log/no log 
decision based upon these circumstantial facts.

Filters carry names and can be specified in two different ways in the Log4perl
configuration file: As subroutines or as filter classes. Here's a 
simple filter named C<MyFilter> which just verifies that the 
oncoming message matches the regular expression C</let this through/i>:

    log4perl.filter.MyFilter        = sub { /let this through/i }

It exploits the fact that when the filter is called on a message,
Perl's special C<$_> variable will be set to the (rendered) message
to be logged. The filter subroutine is expected to return a true value 
if it wants the message to be logged or a false value if doesn't.
Also, Log::Log4perl will pass the same arguments to the filter
function as it would to the corresponding appender. Here's an
example of a filter checking the priority of the oncoming message:

    log4perl.filter.MyFilter        = sub {  \
         my %p = @_;                         \
         (%p{log4p_level} == WARN) ? 1 : 0;  \
                                          }

If the message priority equals C<WARN>, it returns a true value, causing
the message to be logged. For common tasks like this, there's already a 
set of predefined filters available. To perform a level match, it's
much cleaner to use Log4perl's C<LevelMatch> filter instead:

    log4perl.filter.MyFilter = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MyFilter.LevelToMatch = WARN

Once a filter has been defined by name and class, its values can be
assigned to its attributes, just as the C<WARN> value to the 
C<LevelToMatch> attribute above.

=head2 Attaching a filter to an appender

Attaching a filter to an appender is as easy as assigning its name to
the appender's C<Filter> attribute:

    log4perl.appender.MyAppender = MyFilter

This will cause C<Log::Log4perl> to call the filter subroutine/method
every time a message is supposed to be passed to the appender. Depending
on the filter's return value, C<Log::Log4perl> will either continue as
planned or withdraw.

=head2 Combining filters with Log::Log4perl::Filter::Bool

Sometimes, it's useful to combine the output of various filters to
arrive at a log/no log deciscion. While Log4j, Log4perl's mother ship,
chose to implement this feature as a filter chain, similar to Linux' IP chains,
Log4perl tries a different approach. 

Typically, filter results will not need to be passed along in chains but 
combined in a programmatic manner using boolean logic. "Log if
this filter says 'yes' and that filter says 'no'" 
is a fairly common requirement but hard to implement as a chain.

C<Log::Log4perl::Filter::Bool> is a special predefined custom filter
for Log4perl which combines the results of other custom filters 
in arbitrary ways, using boolean expressions:

    log4perl.logger = WARN, AppWarn, AppError

    log4perl.filter.Match1       = sub { /let this through/ }
    log4perl.filter.Match2       = sub { /and that, too/ }
    log4perl.filter.MyBool       = Log::Log4perl::Filter::Bool
    log4perl.filter.MyBool.logic = Match1 || Match2

    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.Filter = MyBool
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout

C<Log::Log4perl::Filter::Bool>'s boolean expressions allow for combining
different appenders by name using AND (&& or &), OR (|| or |) and NOT (!) as
logical expressions. Parentheses are used for grouping. Precedence follows
standard Perl. Here's a bunch of examples:

    Match1 && !Match2            # Match1 and not Match2
    !(Match1 || Match2)          # Neither Match1 nor Match2
    (Match1 && Match2) || Match3 # Both Match1 and Match2 or Match3

=head2 Writing your own filter classes

If none of Log::Log4perl's predefined filter classes fits your needs,
you can easily roll your own: Just define a new class, derive it
from the base class C<Log::Log4perl::Filter> and define its C<decide>
method:

    package Log::Log4perl::Filter::MyFilter;
    use base Log::Log4perl::Filter;

    sub decide {
         my ($self, %p) = @_;

         # ... decide and return 1 or 0
    }

    1;

Values you've defined for its attributes in Log4perl's configuration file,
it will receive through its C<new> method:

    log4perl.filter.MyFilter       = Log::Log4perl::Filter::MyFilter
    log4perl.filter.MyFilter.color = red

will cause C<Log::Log4perl::Filter::MyFilter>'s constructor to be called
like this:

    Log::Log4perl::Filter::MyFilter->new( color => "red" );

which in turn should be used by the custom filter class to set the
object's attributes, which later on can be consulted inside the
C<decide> call.

=head2 A Practical Example: Level Matching

Let's assume you wanted to have each logging statement written to a
different file, based on the statement's priority. Messages with priority
C<WARN> are supposed to go to C</tmp/app.warn>, events prioritized
as C<ERROR> should end up in C</tmp/app.error>, and so forth.

Now, if you define two appenders C<AppWarn> and C<AppError>
and assign them both to the root logger,
messages bubbling up from any loggers below will be logged by both
appenders because of Log4perl's message propagation feature. If you limit
their exposure via the appender threshold mechanism and set 
C<AppWarn>'s threshold to C<WARN> and C<AppError>'s to C<ERROR>, you'll
still get C<ERROR> messages in C<AppWarn>, because C<AppWarn>'s C<WARN>
setting will just filter out messages with a I<lower> priority than
C<WARN> -- C<ERROR> is higher and will be allowed to pass through.

What we need is a custom filter for both appenders verifying that
the priority of the oncoming messages exactly I<matches> the priority 
the appender is supposed to log messages of:

    log4perl.logger = WARN, AppWarn, AppError

        # Filter to match level ERROR
    log4perl.filter.MatchError = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchError.LevelToMatch = ERROR

        # Filter to match level WARN
    log4perl.filter.MatchWarn  = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.MatchWarn.LevelToMatch = WARN

        # Error appender
    log4perl.appender.AppError = Log::Dispatch::File
    log4perl.appender.AppError.filename = /tmp/app.err
    log4perl.appender.AppError.layout   = SimpleLayout
    log4perl.appender.AppError.Filter   = MatchError

        # Warning appender
    log4perl.appender.AppWarn = Log::Dispatch::File
    log4perl.appender.AppWarn.filename = /tmp/app.warn
    log4perl.appender.AppWarn.layout   = SimpleLayout
    log4perl.appender.AppWarn.Filter   = MatchWarn

This will direct WARN messages and /tmp/app.warn and ERROR messages
to /tmp/app.error without overlaps.

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>, 2003

=cut
