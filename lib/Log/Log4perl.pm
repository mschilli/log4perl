##################################################
package Log::Log4perl;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Logger;
use Log::Log4perl::Config;

our $VERSION = '0.14';

##################################################
sub new {
##################################################
    die "THIS CLASS ISN'T FOR DIRECT USE. " .
        "PLEASE CHECK 'perldoc __PACKAGE__'.";
}

##################################################
sub reset {
##################################################
    # Delegate this to the logger ...
    return Log::Log4perl::Logger->reset();
}

##################################################
sub init {
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init(@args);
}

##################################################
sub get_logger {
##################################################
    my($class, @args) = @_;

    # Delegate this to the logger module
    return Log::Log4perl::Logger->get_logger(@args);
}

1;

__END__

=head1 NAME

Log::Log4perl - Log4j implementation for Perl

=head1 DESCRIPTION

C<Log::Log4perl> implements the widely popular C<Log4j> logging
package ([1]) in pure Perl.

A WORD OF CAUTION: THIS LIBRARY IS UNDER HEAVY CONSTRUCTION AND
CURRENTLY IN 'ALPHA' STATE. THE MODULE IS ALWAYS GUARANTEED TO PASS THE
CONTINUALLY GROWING REGRESSION TEST SUITE, BUT IF YOU'RE PLANNING TO USE
IT ON A PRODUCTION SYSTEM, PLEASE WAIT UNTIL THE VERSION NUMBERS HAVE
REACHED 1.0 OR BETTER.

Logging beats a debugger when you want to know what's going on 
in your code during runtime. However, traditional logging packages
are too static and generate a flood of log messages in your log files
that won't help you.

C<Log::Log4perl> is different. It allows you to control the amount of 
logging messages generated at three different levels:

=over 4

=item *

At a central location in your system (either in a configuration file or
in the startup code) you specify I<which components> (classes, functions) 
of your system should generate logs.

=item *

You specify how detailed the logging of these components should be by
specifying logging I<levels>.

=item *

You also specify which so-called I<appenders> you want to feed your
log messages to ("Print it to the screen and also append it to /tmp/my.log")
and which format ("Write the date first, then the file name and line 
number, and then the log message") they should be in.

=back

This is a very powerful and flexible mechanism. You can turn on and off
your logs at any time, specify the level of detail and make that
dependent on the subsystem that's currently executed. 

Let me give you an example: You might 
find out that your system has a problem in the 
C<MySystem::Helpers::ScanDir>
component. Turning on detailed debugging logs all over the system would
generate a flood of useless log messages and bog your system down beyond
recognition. With C<Log::Log4perl>, however, you can tell the system:
"Continue to log only severe errors in the log file. Open a second
log file, turn on full debug logs in the C<MySystem::Helpers::ScanDir>
component and dump all messages originating from there into the new
log file". And all this is possible by just changing the parameters
in a configuration file, which your system can re-read even 
while it's running!

=head1 How to use it

The C<Log::Log4perl> package can be initialized in two ways: Either
via Perl commands or via a C<lib4j>-style configuration file.

=head2 Initialize via a configuration file

This is the easiest way to prepare your system for using
C<Log::Log4perl>. Use a configuration file like this:

    ############################################################
    # A simple root logger with a Log::Dispatch file appender
    # in Perl.
    # Mike Schilli 2002 m@perlmeister.com
    ############################################################
    log4j.rootLogger=error, LOGFILE
    
    log4j.appender.LOGFILE=Log::Dispatch::File
    log4j.appender.LOGFILE.filename=/var/log/myerrs.log
    log4j.appender.LOGFILE.mode=append
    
    log4j.appender.LOGFILE.layout=org.apache.log4j.PatternLayout
    log4j.appender.LOGFILE.layout.ConversionPattern=[%r] %F %L %c - %m%n

These lines define your standard logger that's appending severe
errors to C</var/log/myerrs.log>, using the format

    [millisecs] source-filename line-number class - message newline

Check [1] for more details on how to define loggers with
C<Log4j>, the equivalent Java implementation of this package.

Assuming that this file is saved as C<log.conf>, you need to 
read it in in the startup section of your code, using the following
commands:

  use Log::Log4perl;
  Log::Log4perl->init("log.conf");

After that's done I<somewhere> in the code, you can retrieve
logger objects I<anywhere> in the code. Note that
there's no need to carry any logger references around with your 
functions and methods. You can get a logger anytime via a singleton
mechanism:

    package My::MegaPackage;

    sub some_method {
        my($param) = @_;

        use  Log::Log4perl;
        my $log = Log::Log4perl->get_logger("My::MegaPackage");

        $log->debug("Debug message");
        $log->info("Info message");
        $log->error("Error message");

        ...
    }

With the configuration file above, C<Log::Log4perl> will write
"Error message" to the specified log file, but won't do anything for 
the C<debug()> and C<info()> calls, because the log level has been set
to C<ERROR> for all components in the first line of 
configuration file shown above.

Why C<Log::Log4perl-E<gt>get_logger> and
not C<Log::Log4perl-E<gt>new>? We don't want to create a new
object every time. Usually in OO-Programming, you create an object
once and use the reference to it to call its methods. However,
this requires that you pass around the object to all functions
and the last thing we want is pollute each and every function/method
we're using with a handle to the C<Logger>:

    sub function {  # Brrrr!!
        my($logger, $some, $other, $parameters) = @_;
    }

Instead, if a function/method wants a reference to the logger, it
just calls the Logger's static C<get_logger()> method to obtain
a reference to the I<one and only> possible logger object of
a certain category.
That's called a I<singleton> if you're a Gamma fan.

How does the logger know
which messages it is supposed to log and which ones to suppress?
C<Log::Log4perl> works with inheritence: The config file above didn't 
specify anything about C<My::MegaPackage>. 
And yet, we've defined a logger of the category 
C<My::MegaPackage>.
In this case, C<Log::Log4perl> will walk up the class hierarchy
(C<My> and then the we're at the root) to figure out if a log level is
defined somewhere. In the case above, the log level at the root
(root I<always> defines a log level, but not necessary an appender)
defines that 
the log level is supposed to be C<ERROR> -- meaning that I<debug>
and I<info> messages are suppressed.

=head2 Configuration within Perl

Initializing the logger can certainly also be done from within Perl.
At last, this is what C<Log::Log4perl::Config> does behind the scenes.
At the Perl level, we can specify exactly, which loggers work with
which appenders and which layouts.

Here's the code for a root logger which sends error and
higher prioritized messages to the C</tmp/my.log> logfile:

  # Initialize the logger

  use Log::Log4perl;
  use Log::Dispatch::File;
  use Log::Log4perl::Layout;

  my $disp   = Log::Dispatch::File->new(
                   name      => "screenlog",
                   filename  => "/tmp/my.log",
                   min_level => "debug",
               );

  my $log = Log::Log4perl->get_logger(""); # root logger
  $log->layout("[%r] %F %L %m%n");
  $log->add_appender($disp);

And after this, we can, again, start logging I<anywhere> in the system
like this (remember, we don't want to pass around references, so
we just get the logger via the singleton-mechanism):

  # Use the logger

  use Log::Log4perl;
  my $log = Log::Log4perl->get_logger("My::Component");
  $log->debug("Debug Message");
  $log->info("Info Message");
  $log->error("Error Message");

=head2 Log Levels

There's five predefined log levels: C<FATAL>, C<ERROR>, C<WARN>, C<INFO> 
and <DEBUG> (in descending priority). Your configured logging level
has to at least match the priority of the logging message.

If your configured logging level is C<WARN>, then messages logged 
with C<info()> and C<debug()> message will be suppressed. 
C<fatal()>, C<error()> and C<warn()> will make their way, though,
because their priority is higher or equal than the configured setting.

Instead of calling the methods

    $logger->debug("...");  # Log a debug message
    $logger->info("...");   # Log a info message
    $logger->warn("...");   # Log a warn message
    $logger->error("...");  # Log a error message
    $logger->fatal("...");  # Log a fatal message

you could also call the C<log()> method with the appropriate level
using the constants defined in C<Log::Log4perl::Level>:

    use Log::Log4perl::Level;

    $logger->log($DEBUG, "...");
    $logger->log($INFO, "...");
    $logger->log($WARN, "...");
    $logger->log($ERROR, "...");
    $logger->log($FATAL, "...");

But nobody does that, really. Neither does anyone need more logging
levels than these predefined ones. If you think you do, I would
suggest you look into steering your logging behaviour via
the category mechanism.

The constants defined in C<Log::Log4perl::Level>
will come in handy later, however, when we want to block unnecessary
expensive parameter construction in case the logging level is too
low to log anyway like in:

    if($logger->level() >= $ERROR) {
        $logger->error("Erroneous array: @super_long_array");
    }

If we just had written

    $logger->error("Erroneous array: @super_long_array");

then Perl would have interpolated
C<@super_long_array> into the string via an expensive operation
only to figure out shortly after that the string can be ignored
entirely because the configured logging level is lower than C<$ERROR>.

The to-be-logged
message passed to all of the functions described above can
consist of an arbitrary number of arguments, which the logging functions
just chain together to a single string. Therefore

    $logger->debug("Hello ", "World", "!");  # and
    $logger->debug("Hello World!");

are identical.

=head2 Appenders

If you don't define any appenders, nothing will happen. Appenders will
be triggered whenever the configured logging level requires a message
to be logged and not suppressed.

C<Log::Log4perl> doesn't define any appenders by default, not even the root
logger has one.

C<Log::Log4perl> utilizes I<Dave Rolskys> excellent C<Log::Dispatch>
module to implement a wide variety of different appenders. You can have
your messages written to STDOUT, to a file or to a database -- or to
all of them at once if you desire so.

Here's the list of appender modules currently available via C<Log::Dispatch>:

       Log::Dispatch::ApacheLog
       Log::Dispatch::DBI
       Log::Dispatch::Email,
       Log::Dispatch::Email::MailSend,
       Log::Dispatch::Email::MailSendmail,
       Log::Dispatch::Email::MIMELite
       Log::Dispatch::File
       Log::Dispatch::Handle
       Log::Dispatch::Screen
       Log::Dispatch::Syslog
       Log::Dispatch::Tk

Now let's assume that we want to go overboard and log C<info()> or
higher prioritized messages in the C<My::Category> class
to both STDOUT and to a log file, say C</tmp/my.log>.
In the initialisation section of your system,
just define two appenders using the readily available
C<Log::Dispatch::File> and C<Log::Dispatch::Screen> modules:

  ########################
  # Initialisation section
  ########################
  use Log::Log4perl;
  use Log::Dispatch::File;
  use Log::Log4perl::Layout;
  use Log::Log4perl::Level;

  my $log = Log::Log4perl->get_logger("My::Category");

  my $file_appender = Log::Dispatch::File->new(
      name      => "filelog",
      filename  => "/tmp/my.log",
      min_level => "debug",
  );

  my $stdout_appender = Log::Dispatch::Screen->new(
      name      => "screenlog",
      stderr    => 0,
      min_level => "debug",
  );

  $log->level($INFO);
  $log->layout("screenlog", "[%r] %F %L %m%n");
  $log->layout("filelog", "[%r] %F %L %m%n");
  $log->add_appender("screenlog", $stdout_appender);
  $log->add_appender("filelog", $file_appender);

Please note that the constructor calls to the 
C<Log::Dispatch> objects are all setting the mandatory 
C<min_level> parameter to C<debug>. This is because we want the
C<Log::Dispatch> objects to blindly log everything we send them
(C<debug> is their lowest setting) because I<we> in C<Log::Log4perl>
want to call the shots and decide on when and what to log.

The call to the I<layout()> method specifies the format in which the
message is logged in the appender specified by name. The formats shown above 
are logging not only the message but also the number of milliseconds since
the program has started (%r), the name of the file the call to the logger
has happened and the line number there (%F and %L), the message itself
(%m) and a OS-specific newline character (%n).
For more detailed info on layout formats, see L<Layouts>.
If you don't specify a layout, the logger will just log the plain
message.

Once the initialisation shown above has happened once, typically in
the startup code of your system, just use this logger anywhere in 
your system (or better yet, only in C<My::Category>, since we
defined it this way) as often as you like:

  ##########################
  # ... in some function ...
  ##########################
  my $log = Log::Log4perl->get_logger("My::Category");
  $log->info("This is an informational message");

Above, we chose to define a I<category> logger (C<My::Category>)
in a specific way. This will cause only messages originating from
this specific category logger to be logged in the defined format
and locations.

Instead, 
we could have configured the I<root> logger with the appenders and layout
shown above. Now

  ##########################
  # ... in some function ...
  ##########################
  my $log = Log::Log4perl->get_logger("My::Category");
  $log->info("This is an informational message");

will trigger a logger with no layout or appenders or even a level defined.
This logger, however, will inherit the level from categories up the
hierarchy -- ultimately the root logger, since there's no C<My> logger. 
Once it detects that it needs
to log a message, it will first try to find its own appenders
(which it doesn't have any of) and then walk up the hierarchy (first C<My>, 
then C<root>) to call any appenders defined there.

This will result in exactly the same behaviour as shown above -- with the 
exception that other category loggers could also use the root logger's 
appenders and layouts, but could certainly define their own categories
and levels.

=head2 Turn off a component
 
C<Log4perl> doesn't only allow you to selectively switch I<on> a category
of log messages, you can also use the mechanism to selectively I<disable>
logging in certain components whereas logging is kept turned on in higher-level
categories. This mechanism comes in handy if you find that while bumping 
up the logging level of a high-level (i. e. close to root) category, 
that one component logs more than it should, 

Here's how it works: 

    ############################################################
    # Turn off logging in a lower-level category while keeping
    # it active in higher-level categories.
    ############################################################
    log4j.rootLogger=debug, LOGFILE
    log4j.logger.deep.down.the.hierarchy = error, LOGFILE

    # ... Define appenders ...

This way, log messages issued from within 
C<Deep::Down::The::Hierarchy> and below will be
logged only if they're C<error> or worse, while in all other system components
even C<debug> messages will be logged.

=head2 Configuration files

As shown above, you can define C<Log::Log4perl> loggers both from within
your Perl code or from configuration files. The latter have the unbeatible
advantage that you can modify your system's logging behaviour without 
interfering with the code at all. So even if your code is being run by 
somebody who's totally oblivious to Perl, they still can adapt the
module's logging behaviour to their needs.

C<Log::Log4perl> has been designed to understand C<Log4j> configuration
files -- as used by the original Java implementation. Instead of 
reiterating the format description in [1], let me just list three
examples (also derived from [1]), which should also illustrate
how it works:

    log4j.rootLogger=DEBUG, A1
    log4j.appender.A1=ConsoleAppender
    log4j.appender.A1.layout=org.apache.log4j.PatternLayout
    log4j.appender.A1.layout.ConversionPattern=%-4r [%t] %-5p %c %x - %m%n

This enables messages of priority C<debug> or higher in the root
hierarchy and has the system write them to the console. 
C<ConsoleAppender> is a Java appender, but C<Log::Log4perl> jumps
through a significant number of hoops internally to map these to their
corresponding Perl classes, C<Log::Dispatch::Screen> in this case.

Second example:

    log4j.rootLogger=DEBUG, A1
    log4j.appender.A1=Log::Dispatch::Screen
    log4j.appender.A1.layout=org.apache.log4j.PatternLayout
    log4j.appender.A1.layout.ConversionPattern=%d [%t] %-5p %c - %m%n
    log4j.logger.com.foo=WARN

This defines two loggers: The root logger and the C<com.foo> logger.
The root logger is easily triggered by debug-messages, 
but the C<com.foo> logger makes sure that messages issued within
the C<Com::Foo> component and below are only forwarded to the appender
if they're of priority I<warning> or higher. 

Note that the C<com.foo> logger doesn't define an appender. Therefore,
it will just propagate the message up the hierarchy until the root logger
picks it up and forwards it to the one and only appender of the root
category, using the format defined for it.

Third example:

    log4j.rootLogger=debug, stdout, R
    log4j.appender.stdout=org.apache.log4j.ConsoleAppender
    log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
    log4j.appender.stdout.layout.ConversionPattern=%5p [%t] (%F:%L) - %m%n
    log4j.appender.R=org.apache.log4j.FileAppender
    log4j.appender.R.File=example.log
    log4j.appender.R.layout=org.apache.log4j.PatternLayout
    log4j.appender.R.layout.ConversionPattern=%p %t %c - %m%n

The root logger defines two appenders here: C<stdout>, which uses 
C<org.apache.log4j.ConsoleAppender> (ultimately mapped by C<Log::Log4perl>
to C<Log::Dispatch::Screen>) to write to the screen. And
C<R>, a C<org.apache.log4j.RollingFileAppender> 
(ultimately mapped by C<Log::Log4perl> to 
C<Log::Dispatch::File> with the C<File> attribute specifying the
log file.

=head2 Layout patterns

Instead of copying the original documentation from which this format
has been derived for C<Log::Log4perl>, please refer to it directly:

    http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html

Only exceptions so far are C<%t>, C<%x> and C<%X> which aren't implemented
yet and C<%d> which stubburnly uses C<yyyy/mm/dd hh:mm:ss> as the time
stamp format (no support yet for C<%d{yada}>.

=head2 Penalties

Logging comes with a price tag. C<Log::Log4perl> is currently being optimized
to allow for maximum performance, both with logging enabled and disabled.

But you need to be aware that there's a small hit every time your code
encounters a log statement -- no matter if logging is enabled or not. 
C<Log::Log4perl> has been designed to keep this so low that it will
be unnoticable to most applications.

Here's a couple of tricks which help C<Log::Log4perl> to avoid
unnecessary delays:

You can save serious time if you're logging something like

        # Expensive in non-debug mode!
    for (@super_long_array) {
        $Logger->debug("Element: $_\n");
    }

and C<@super_long_array> is fairly big, so looping through it is pretty
expensive. Only you, the programmer, knows that going through that C<for>
loop can be skipped entirely if the current logging level for the 
actual component is higher than C<debug>.
In this case, use this instead:

        # Cheap in non-debug mode!
    if($Logger->is_debug()) {
        for (@super_long_array) {
            $Logger->debug("Element: $_\n");
        }
    }

=head1 Categories

C<Log::Log4perl> uses I<categories> to determine if a log statement in
a component should be executed or suppressed at the current logging level.
Most of the time, these categories are just the classes the log statements
are located in:

    package Candy::Twix;

    sub new { 
        my $logger = Log::Log4perl->new("Candy::Twix");
        $logger->debug("Creating a new Twix bar");
        bless {}, shift;
    }
 
    # ...

    package Candy::Snickers;

    sub new { 
        my $logger = Log::Log4perl->new("Candy.Snickers");
        $logger->debug("Creating a new Snickers bar");
        bless {}, shift;
    }

    # ...

    package main;
    Log::Log4perl->init("mylogdefs.conf") or 
        die "Whoa, cannot read mylogdefs.conf!";

        # => "LOG> Creating a new Snickers bar"
    my $first = Candy::Snickers->new();
        # => "LOG> Creating a new Twix bar"
    my $second = Candy::Twix->new();

Note that you can separate your category hierarchy levels
using either dots like
in Java (.) or double-colons (::) like in Perl. Both notations
are equivalent and are handled the same way internally.

However, categories are just there to make
use of inheritance: if you invoke a logger in a sub-category, 
it will bubble up the hierarchy and call the appropriate appenders.
Internally, categories not related to the class hierarchy of the program
at all -- they're purely virtual. You can use arbitrary categories --
for example in the following program, which isn't oo-style, but
procedural:

    sub print_portfolio {

        my $log = Log::Log4perl->new("user.portfolio");
        $log->debug("Quotes requested: @_");

        for(@_) {
            print "$_: ", get_quote($_), "\n";
        }
    }

    sub get_quote {

        my $log = Log::Log4perl->new("internet.quotesystem");
        $log->debug("Fetching quote: $_[0]");

        return yahoo_quote($_[0]);
    }

The logger in first function, C<print_portfolio>, is assigned the
(virtual) C<user.portfolio> category. Depending on the C<Log4perl>
configuration, this will either call a C<user.portfolio> appender,
a C<user> appender, or an appender assigned to root -- without
C<user.portfolio> having any relevance to the class system used in 
the program.
The logger in the second function adheres to the 
C<internet.quotesystem> category -- again, maybe because it's bundled 
with other Internet functions, but not because there would be
a class of this name somewhere.

However, be careful, don't go overboard: if you're developing a system
in object-oriented style, using the class hierarchy is usually your best
choice. Think about the people taking over your code one day: The
class hierarchy is probably what they know right up front, so it's easy
for them to tune the logging to their needs.

=head1 How about Log::Dispatch::Config?

Yeah, I've seen it. I like it, but I think it is too dependent
on defining everything in a configuration file.
I've designed C<Log::Log4perl> to be more flexible.

=head1 AUTHORS

    Mike Schilli, <m@perlmeister.com>
    Kevin Goess, <cpan@goess.org>

=head1 INSTALLATION

C<Log::Log4perl> needs C<Log::Dispatch> (2.00 or better) and
C<Time::HiRes> (1.20 or better) from CPAN. They're automatically fetched
if you're using the CPAN shell (CPAN.pm), because they're listed as 
requirements in Makefile.PL.

Manual installation works as usual with

    perl Makefile.PL
    make
    make test
    make install

=head1 DEVELOPMENT

C<Log::Log4perl> is under heavy development. The latest CVS tarball
can be obtained from sourcforge, check C<http://log4perl.sorceforge.net>
for details. Bug reports and feedback are always welcome, just email
to the authors.

=head1 REFERENCES

=over 4

=item [1]

Ceki Gülcü, "Short introduction to log4j",
http://jakarta.apache.org/log4j/docs/manual.html

=item [2]

Vipan Singla, "Don't Use System.out.println! Use Log4j.",
http://www.vipan.com/htdocs/log4jhelp.html

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli E<lt>m@perlmeister.comE<gt> and Kevin Goess
E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
