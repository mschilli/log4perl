##################################################
package Log::Log4perl;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Log::Dispatch::Screen;
use Log::Log4perl::Appender;

our $VERSION = '0.23';

   # set this to '1' if you're using a wrapper
   # around Log::Log4perl
our $caller_depth = 0;

##################################################
sub import {
##################################################
    my($class) = shift;

    no strict qw(refs);

    my(%tags) = map { $_ => 1 } @_;

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        $tags{':levels'} = 1;
        $tags{'get_logger'} = 1;
    }

    if(exists $tags{get_logger}) {
        # Export get_logger into the calling module's 
        my $caller_pkg = caller();

        *{"$caller_pkg\::get_logger"} = *get_logger;

        delete $tags{get_logger};
    }

    if(exists $tags{':levels'}) {
        # Export log levels ($DEBUG, $INFO etc.) from Log4perl::Level
        my $caller_pkg = caller();

        for my $key (keys %Log::Log4perl::Level::PRIORITY) {
            my $name  = "$caller_pkg\::$key";
               # Need to split this up in two lines, or CVS will
               # mess it up.
            my $value = $
                        Log::Log4perl::Level::PRIORITY{$key};
            *{"$name"} = \$value;
        }

        delete $tags{':levels'};
    }

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        delete $tags{':easy'};
    }

    if(keys %tags) {
        # We received an Option we couldn't understand.
        die "Unknown Option(s): @{[keys %tags]}";
    }
}

##################################################
sub new {
##################################################
    die "THIS CLASS ISN'T FOR DIRECT USE. " .
        "PLEASE CHECK 'perldoc " . __PACKAGE__ . "'.";
}

##################################################
sub reset { # Mainly for debugging/testing
##################################################
    # Delegate this to the logger ...
    return Log::Log4perl::Logger->reset();
}

##################################################
sub init { # Read the config file
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
sub init_and_watch { 
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init_and_watch(@args);
}


##################################################
sub easy_init { # Initialize the root logger with a screen appender
##################################################
    my($class, $level) = @_;

    # Did somebody call us with Log::Log4perl::easy_init()?
    if(!defined $level and $class =~ /^\d+$/) {
        $level = $class;
    }

    $level = $DEBUG unless defined $level;

    my $app = Log::Log4perl::Appender->new("Log::Dispatch::Screen");
    my $layout = Log::Log4perl::Layout::PatternLayout->new(
                     "%d %p> %F{1}:%L %M - %m%n");
    $app->layout($layout);

    my $logger = Log::Log4perl->get_logger("");
    $logger->level($level);
    $logger->add_appender($app);
}

##################################################
sub get_logger {  # Get an instance (shortcut)
##################################################
    my($class, @args) = @_;

    if(!defined $class) {
        # Called as ::get_logger()
        unshift(@args, scalar caller());
    } elsif($class eq __PACKAGE__ and !defined $args[0]) {
        # Called as ->get_logger()
        unshift(@args, scalar caller());
    } elsif($class ne __PACKAGE__) {
        # Called as ::get_logger($category)
        unshift(@args, $class);
    } else {
        # Called as ->get_logger($category)
    }

    # Delegate this to the logger module
    return Log::Log4perl::Logger->get_logger(@args);
}

1;

__END__

=head1 NAME

Log::Log4perl - Log4j implementation for Perl

=head1 SYNOPSIS
 
    Log::Log4perl::init('/etc/log4perl.conf');
    
    --or--
    
    Log::Log4perl::init_and_watch('/etc/log4perl.conf',10);
    
    --then--
    
    
    $logger = Log::Log4perl->get_logger('house.bedrm.desk.topdrwr');
    
    $logger->debug('this is a debug message');
    $logger->info('this is an info message');
    $logger->warn('etc');
    $logger->error('..');
    $logger->fatal('..');
    
    #####/etc/log4perl.conf###################
    log4j.category.house              = WARN,  FileAppndr1
    log4j.category.house.bedroom.desk = DEBUG,  FileAppndr1
    
    log4j.appender.FileAppndr1          = Log::Dispatch::File
    log4j.appender.FileAppndr1.filename = desk.log 
    log4j.appender.FileAppndr1.layout   = \
                            Log::Log4perl::Layout::SimpleLayout
    ###########################################
       
=head1 ABSTRACT

    Log::Log4perl provides a powerful logging API to your application,

=head1 DESCRIPTION

Log::Log4perl lets you remote-control and fine-tune the logging behaviour
of your system from the outside. It implements the widely popular 
(Java-based) Log4j logging package in pure Perl ([1]).

A WORD OF CAUTION: THIS LIBRARY IS ALPHA SOFTWARE AND STILL 
UNDER CONSTRUCTION -- ON
http://log4perl.sourceforge.net YOU'LL GET THE LATEST SCOOP.
THE API HAS REACHED A MATURE STATE, WE WILL NOT CHANGE IT UNLESS FOR
A GOOD REASON.

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

Check L<Configuration files> for more details on how to control
your loggers using a configuration file.

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
  use Log::Dispatch::Screen;
  use Log::Log4perl::Appender;

  my $app = Log::Log4perl::Appender->new("Log::Dispatch::Screen");
  my $layout = Log::Log4perl::Layout::PatternLayout
                                        ->new("%d> %F %L %m %n");
  $app->layout($layout);

  my $logger = Log::Log4perl->get_logger("My.Component");
  $logger->add_appender($app);

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
and C<DEBUG> (in descending priority). Your configured logging level
has to at least match the priority of the logging message.

If your configured logging level is C<WARN>, then messages logged 
with C<info()> and C<debug()> message will be suppressed. 
C<fatal()>, C<error()> and C<warn()> will make their way through,
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

If you need to find out if the currently configured logging
level would allow a logger's logging statement to go through, use the
logger's C<is_I<level>()> methods:

    $logger->is_debug()    # True if debug messages would go through
    $logger->is_info()     # True if info messages would go through
    $logger->is_warn()     # True if warn messages would go through
    $logger->is_error()    # True if error messages would go through
    $logger->is_fatal()    # True if fatal messages would go through

Example: C<$logger-E<gt>is_warn()> returns true if the logger's current
level, as derived from either the logger's category (or, in absence of
that, one of the logger's parent's level setting) is 
C<$WARN>, C<$ERROR> or C<$FATAL>.

These level checking functions
will come in handy later, when we want to block unnecessary
expensive parameter construction in case the logging level is too
low to log the statement anyway, like in:

    if($logger->is_error()) {
        $logger->error("Erroneous array: @super_long_array");
    }

If we had just written

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

=head2 Log and die or warn

Often, when you croak / carp / warn / die, you want to log those messages.
Rather than doing the following:

    $logger->fatal($err) && die($err);

you can use the following:

    $logger->logwarn();
    $logger->logdie();

These print out log messages in the WARN and FATAL level, respectively,
and then call the built-in warn() and die() functions. Since there is
an ERROR level between WARN and FATAL, there are two additional helper
functions in case you'd like to use ERROR for either warn() or die():

    $logger->error_warn();
    $logger->error_die();

Finally, there's the Carp functions that do just what the Carp functions
do, but with logging:

    $logger->logcarp();        # warn w/ 1-level stack trace
    $logger->logcluck();       # warn w/ full stack trace
    $logger->logcroak();       # die w/ 1-level stack trace
    $logger->logconfess();     # die w/ full stack trace

=head2 Appenders

If you don't define any appenders, nothing will happen. Appenders will
be triggered whenever the configured logging level requires a message
to be logged and not suppressed.

C<Log::Log4perl> doesn't define any appenders by default, not even the root
logger has one.

C<Log::Log4perl> utilizes I<Dave Rolskys> excellent C<Log::Dispatch>
module to implement a wide variety of different appenders. You can have
your messages written to STDOUT, to a file or to a database -- or to
all of them at once if you desire to do so.

Here's the list of appender modules currently available via C<Log::Dispatch>:

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

For additional information on appenders, please check the
L<Log::Log4perl::Appender> manual page.

Now let's assume that we want to go overboard and log C<info()> or
higher prioritized messages in the C<My::Category> class
to both STDOUT and to a log file, say C</tmp/my.log>.
In the initialisation section of your system,
just define two appenders using the readily available
C<Log::Dispatch::File> and C<Log::Dispatch::Screen> modules
via the C<Log::Log4perl::Appender> wrapper:

  ########################
  # Initialisation section
  ########################
  use Log::Log4perl;
  use Log::Log4perl::Layout;
  use Log::Log4perl::Level;

     # Define a category logger
  my $log = Log::Log4perl->get_logger("My::Category");

     # Define a layout
  my $layout = Log::Log4perl->new("[%r] %F %L %m%n");

     # Define a file appender
  my $file_appender = Log::Log4perl::Appender->new(
                          "Log::Dispatch::File",
                          name      => "filelog",
                          filename  => "/tmp/my.log");


     # Define a stdout appender
  my $stdout_appender =  Log::Log4perl::Appender->new(
                          "Log::Dispatch::Screen",
                          name      => "screenlog",
                          stderr    => 0);

     # Have both appenders use the same layout (could be different)
  $stdout_appender->layout($layout);
  $file_appender->layout($layout);

  $log->add_appender($stdout_appender);
  $log->add_appender($file_appender);
  $log->level($INFO);

Please note the class of the C<Log::Dispatch> object is passed as a
I<string> to C<Log::Log4perl::Appender> in the I<first> argument. 
Behind the scenes, C<Log::Log4perl::Appender> will create the necessary
C<Log::Dispatch::*> object and pass along the name value pairs we provided
to C<Log::Log4perl::Appender-E<gt>new()> after the first argument.

The C<name> value is optional and if you don't provide one,
C<Log::Log4perl::Appender-E<gt>new()> will create a unique one for you.
The names and values of additional parameters are dependent on the requirements
of the particular C<Log::Dispatch::*> class and can be looked up in their
manual pages.

On a side note: In case you're wondering if
C<Log::Log4perl::Appender-E<gt>new()> will also take care of the
C<min_level> argument to the C<Log::Dispatch::*> constructors called
behind the scenes -- yes, it does. This is because we want the
C<Log::Dispatch> objects to blindly log everything we send them
(C<debug> is their lowest setting) because I<we> in C<Log::Log4perl>
want to call the shots and decide on when and what to log.

The call to the appender's I<layout()> method specifies the format (as a
previously created C<Log::Log4perl::PatternLayout> object) in which the
message is being logged in the specified appender. The format shown
above is logging not only the message but also the number of
milliseconds since the program has started (%r), the name of the file
the call to the logger has happened and the line number there (%F and
%L), the message itself (%m) and a OS-specific newline character (%n).
For more detailed info on layout formats, see L<Log Layouts>. If you
don't specify a layout, the logger will fall back to
C<Log::Log4perl::SimpleLayout>, which logs the debug level, a hyphen (-)
and the log message.

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

will trigger a logger with no layout or appenders or even a level
defined. This logger, however, will inherit the level from categories up
the hierarchy -- ultimately the root logger, since there's no C<My>
logger. Once it detects that it needs to log a message, it will first
try to find its own appenders (which it doesn't have any of) and then
walk up the hierarchy (first C<My>, then C<root>) to call any appenders
defined there.

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

=head2 Log Layouts

If the logging engine passes a message to an appender, because it thinks
it should be logged, the appender doesn't just
write it out haphazardly. There's ways to tell the appender how to format
the message and add all sorts of interesting data to it: The date and
time when the event happened, the file, the line number, the
debug level of the logger and others.

There's currently two layouts defined in C<Log::Log4perl>: 
C<Log::Log4perl::Layout::SimpleLayout> and
C<Log::Log4perl::Layout::Patternlayout>:

=over 4 

=item C<Log::Log4perl::SimpleLayout> 

formats a message in a simple
way and just prepends it by the debug level and a hyphen:
C<"$level - $message>, for example C<"FATAL - Can't open password file">.

=item C<Log::Log4perl::PatternLayout> 

on the other hand is very powerful and 
allows for a very flexible format in C<printf>-style. The format
string can contain a number of placeholders which will be
replaced by the logging engine when it's time to log the message:

    %c Category of the logging event.
    %C Fully qualified package (or class) name of the caller
    %d Current date in yyyy/mm/dd hh:mm:ss format
    %F File where the logging event occurred
    %l Fully qualified name of the calling method followed by the
       callers source the file name and line number between 
       parentheses.
    %L Line number within the file where the log statement was issued
    %m The message to be logged
    %M Method or function where the logging request was issued
    %n Newline (OS-independent)
    %p Priority of the logging event
    %r Number of milliseconds elapsed from program start to logging 
       event
    %% A literal percent (%) sign

Also, C<%d> can be fine-tuned to display only certain characteristics
of a date, according to the SimpleDateFormat in the Java World
(http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html)

In this way, C<%d{HH:mm}> displays only hours and minutes of the current date,
while C<%d{yy, EEEE}> displays a two-digit year, followed by a spelled-out
(like C<Wednesday>). 

Similar options are available for shrinking the displayed category or
limit file/path components, C<%f{1}> only displays the source file I<name>
without any path components while C<%f> logs the full path. %c{2} only
logs the last two components of the current category, C<Foo::Bar::Baz> 
becomes C<Bar::Baz> and saves space.

See L<Log::Log4perl::Layout::PatternLayout> for details.

=back

All placeholders are quantifiable, just like in I<printf>. Following this 
tradition, C<%-20c> will reserve 20 chars for the category and right-justify it.

Layouts are objects, here's how you create them:

        # Create a simple layout
    my $simple = Log::Log4perl::SimpleLayout();

        # create a flexible layout:
        # ("yyyy/mm/dd hh:mm:ss (file:lineno)> message\n")
    my $pattern = Log::Log4perl::PatternLayout("%d (%F:%L)> %m%n");

Every appender has exactly one layout assigned to it. You assign
the layout to the appender using the appender's C<layout()> object:

    my $app =  Log::Log4perl::Appender->new(
                  "Log::Dispatch::Screen",
                  name      => "screenlog",
                  stderr    => 0);

        # Assign the previously defined flexible layout
    $app->layout($pattern);

        # Add the appender to a previously defined logger
    $logger->add_appender($app);

        # ... and you're good to go!
    $logger->debug("Blah");
        # => "2002/07/10 23:55:35 (test.pl:207)> Blah\n"

If you don't specify a layout for an appender, the logger will fall back 
to C<SimpleLayout>.

For more details on logging and how to use the flexible and the simple
format, check out the original C<log4j> website under

    http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/SimpleLayout.html
    http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html

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

If you're afraid that the way you're generating the parameters to the
of the logging function is fairly expensive, use closures:

        # Passed as subroutine ref
    use Data::Dumper;
    $Logger->debug(sub { Dumper($data) } );

This won't unravel C<$data> via Dumper() unless it's actually needed
because it's logged.

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
Internally, categories are not related to the class hierarchy of the program
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

=head1 Cool Tricks

=head2 Shortcuts

When getting an instance of a logger, instead of saying

    use Log::Log4perl;
    my $logger = Log::Log4perl->get_logger();

it's often more convenient to import the C<get_logger> method from 
C<Log::Log4perl> into the current namespace:

    use Log::Log4perl qw(get_logger);
    my $logger = get_logger();

=head2 Alternative initialization

Instead of having C<init()> read in a configuration file, you can 
also pass in a reference to a string, containing the content of
the file:

    Log::Log4perl->init( \$config_text );

Also, if you've got the C<name=value> pairs of the configuration in
a hash, you can just as well initialized C<Log::Log4perl> with
a reference to it:

    my %key_value_pairs = (
        "log4j.rootLogger"       => "error, LOGFILE",
        "log4j.appender.LOGFILE" => "Log::Dispatch::File",
        ...
    );

    Log::Log4perl->init( \%key_value_pairs );

=head2 Incrementing and Decrementing the Log Levels

Log4perl provides some internal functions for quickly adjusting the
log level from within a running Perl program. 

Now, some people might
argue that you should adjust your levels from within an external 
Log4perl configuration file, but Log4perl is everybody's darling.

Typically run-time adjusting of levels is done
at the beginning, or in response to some external input (like a
"more logging" runtime command for diagnostics).

To increase the level of logging currently being done, use:

    $logger->more_logging($delta);

and to decrease it, use:

    $logger->less_logging($delta);

$delta must be a positive integer (for now, we may fix this later ;).

There are also two equivalent functions:

    $logger->inc_level($delta);
    $logger->dec_level($delta);

They're included to allow you a choice in readability. Some folks
will prefer more/less_logging, as they're fairly clear in what they
do, and allow the programmer not to worry too much about what a Level
is and whether a higher Level means more or less logging. However,
other folks who do understand and have lots of code that deals with
levels will probably prefer the inc_level() and dec_level() methods as
they want to work with Levels and not worry about whether that means
more or less logging. :)

That diatribe aside, typically you'll use more_logging() or inc_level()
as such:

    my $v = 0; # default level of verbosity.
    
    GetOptions("v+" => \$v, ...);

    $logger->more_logging($v);  # inc logging level once for each -v in ARGV

=head2 Custom Log Levels

First off, let me tell you that creating custom levels is heavily
deprechiated by the log4j folks. Indeed, instead of creating additional
levels on top of the predefined DEBUG, INFO, WARN, ERROR and FATAL, 
you should use categories to control the amount of logging smartly,
based on the location of the log-active code in the system.

Nevertheless, 
Log4perl provides a nice way to create custom levels via the 
create_custom_level() routine function. However, this must be done
before the first call to init() or get_logger(). Say you want to create
a NOTIFY logging level that comes after WARN (and thus before INFO).
You'd do such as follows:

    use Log::Log4perl;
    use Log::Log4perl::Level;

    Log::Log4perl::Logger::create_custom_level("NOTIFY", "WARN");

And that's it! create_custom_level() creates the following functions /
variables for level FOO:

    $FOO_INT		# integer to use in toLevel()
    $logger->foo()	# log function to log if level = FOO
    $logger->is_foo()	# true if current level is >= FOO

These levels can also be used in your
config file, but note that your config file probably won't be
portable to another log4perl or log4j environment unless you've
made the appropriate mods there too.

=head1 How about Log::Dispatch::Config?

Tatsuhiko Miyagawa's C<Log::Dispatch::Config> is a very clever 
simplified logger implementation, covering some of the I<log4j>
functionality. Among the things that 
C<Log::Log4perl> can but C<Log::Dispatch::Config> can't are:

=over 4

=item *

You can't assing categories to loggers. For small systems that's fine,
but if you can't turn off and on detailed logging in only a tiny
subsystem of your environment, you're missing out on a majorly
useful log4j feature.

=item *

Defining appender thresholds. Important if you want to solve problems like
"log all messages of level FATAL to STDERR, plus log all DEBUG
messages in C<Foo::Bar> to a log file". If you don't have appenders
thresholds, there's no way to prevent cluttering STDERR with DEBUG messages.

=item *

PatternLayout specifications in accordance with the standard
(e.g. "%d{HH:mm}").

=back

Bottom line: Log::Dispatch::Config is fine for small systems with
simple logging requirements. However, if you're
designing a system with lots of subsystems which you need to control
independantly, you'll love the features of C<Log::Log4perl>,
which is equally easy to use.

=head1 Using Log::Log4perl from wrapper classes

If you don't use C<Log::Log4perl> as described above, 
but from a wrapper class (like your own Logging class which in turn uses
C<Log::Log4perl>),
the pattern layout will generate wrong data for %F, %C, %L and the like.
Reason for this is that C<Log::Log4perl>'s loggers assume a static
caller depth to the application that's using them. If you're using
one (or more) wrapper classes, C<Log::Log4perl> will indicate where
your logger classes called the loggers, not where your application
called your wrapper, which is probably what you want in this case.
But don't dispair, there's a solution: Just increase the value
of C<$Log::Log4perl::caller_depth> (defaults to 0) by one for every
wrapper that's in between your application and C<Log::Log4perl>,
then C<Log::Log4perl> will compensate for the difference.

=head1 EXAMPLE

A simple example to cut-and-paste and get started:

    use Log::Log4perl qw(get_logger);

    my $conf = q(
    log4perl.category.Bar.Twix      = WARN, Screen
    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.layout = \
        Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %m %n
    );
    
    Log::Log4perl::init(\$conf);
    
    my $logger = get_logger("Bar::Twix");
    $logger->error("Blah");

=head1 INSTALLATION

C<Log::Log4perl> needs C<Log::Dispatch> (2.00 or better) from CPAN.
C<Time::HiRes> (1.20 or better) is required only if you need the
fine-grained time stamps of the C<%r> parameter in
C<Log::Log4perl::Layout::PatternLayout>.

C<Log::Dispatch> is automatically fetched from CPAN
if you're using the CPAN shell (CPAN.pm), because it's listed as 
requirement in Makefile.PL.

Manual installation works as usual with

    perl Makefile.PL
    make
    make test
    make install

=head1 DEVELOPMENT

C<Log::Log4perl> is under heavy development. The latest CVS tarball
can be obtained from SourceForge, check C<http://log4perl.sorceforge.net>
for details. Bug reports and feedback are always welcome, just email
to our mailing list shown in L<CONTACT>.

=head1 REFERENCES

=over 4

=item [1]

Ceki Gülcü, "Short introduction to log4j",
http://jakarta.apache.org/log4j/docs/manual.html

=item [2]

Vipan Singla, "Don't Use System.out.println! Use Log4j.",
http://www.vipan.com/htdocs/log4jhelp.html

=item [3]

The Log::Log4perl project home page: http://log4perl.sourceforge.net

=back

=head1 CONTACT

Please send bug reports or requests for enhancements to the authors via 
our log4perl development mailing list: 

log4perl-devel@lists.sourceforge.net

=head1 AUTHORS

    Mike Schilli <m@perlmeister.com>
    Kevin Goess <cpan@goess.org>

    Contributors:

    Chris R. Donnelly <cdonnelly@digitalmotorworks.com>
    Erik Selberg <erik@selberg.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli E<lt>m@perlmeister.comE<gt> and Kevin Goess
E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
