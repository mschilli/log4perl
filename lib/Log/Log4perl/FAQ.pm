1;

__END__

=head1 NAME

Log::Log4perl::FAQ - Frequently Asked Questions on Log::Log4perl

=head1 DESCRIPTION

This FAQ shows a wide variety of 
commonly encountered logging tasks and how to solve them 
in the most elegant way with Log::Log4perl. Most of the time, this will
be just a matter of smartly configuring your Log::Log4perl configuration files.

This document is supposed to grow week by week as the latest
"Log::Log4perl recipe of the week" hits the Log::Log4perl mailing list
at C<log4perl-devel@lists.sourceforge.net>.

=head2 How can I simply log all my ERROR messages to a file?

After pulling in the C<Log::Log4perl> module, just initialize its
behaviour by passing in a configuration to its C<init> method as a string
reference. Then, obtain a logger instance and write out a message
with its C<error()> method:

    use Log::Log4perl qw(get_logger);

        # Define configuration
    my $conf = q(
        log4perl.logger                    = ERROR, FileApp
        log4perl.appender.FileApp          = Log::Dispatch::File
        log4perl.appender.FileApp.filename = test.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
    );

        # Initialize logging behaviour
    Log::Log4perl->init( \$conf );

        # Obtain a logger instance
    my $logger = get_logger("Bar::Twix");
    $logger->error("Oh my, a dreadful error!");
    $logger->warn("Oh my, a dreadful warning!");

This will append something like

    2002/10/29 20:11:55> Oh my, a dreadful error!

to the log file C<test.log>. How does this all work? 

While the Log::Log4perl C<init()> method typically 
takes the name of a configuration file as its input parameter like
in

    Log::Log4perl->init( "/path/mylog.conf" );

the example above shows how to pass in a configuration as text in a 
scalar reference.

The configuration as shown
defines a logger of the root category, which has an appender of type 
C<Log::Dispatch::File> attached. The line

    log4perl.logger = ERROR, FileApp

doesn't list a category, defining a root logger. Compare that with

    log4perl.logger.Bar.Twix = ERROR, FileApp

which would define a logger for the category C<Bar::Twix>,
showing probably different behaviour. C<FileApp> on
the right side of the assignment is
an arbitrarily defined variable name, which is only used to somehow 
reference an appender defined later on.

Appender settings in the configuration are defined as follows:

    log4perl.appender.FileApp          = Log::Dispatch::File
    log4perl.appender.FileApp.filename = test.log

It selects the file appender of the C<Log::Dispatch> hierarchy, 
which is tricked by Log::Log4perl into thinking that it should append to the
file C<test.log> if it already exists. If we wanted to overwrite
a potentially existing file, we would have to explicitly set the
appropriate C<Log::Dispatch::File> parameter C<mode>:

    log4perl.appender.FileApp          = Log::Dispatch::File
    log4perl.appender.FileApp.filename = test.log
    log4perl.appender.FileApp.mode     = write

Also, the configuration defines a PatternLayout format, adding
the nicely formatted current date and time, an arrow (E<gt>) and
a space before the messages, which is then followed by a newline:

    log4perl.appender.FileApp.layout   = PatternLayout
    log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n

Obtaining a logger instance and actually logging something is typically
done in a different system part as the Log::Log4perl initialisation section,
but in this example, it's just done right after init for the 
sake of compactness:

        # Obtain a logger instance
    my $logger = get_logger("Bar::Twix");
    $logger->error("Oh my, a dreadful error!");

This retrieves an instance of the logger of the category C<Bar::Twix>, 
which, as all other categories, inherits behaviour from the root logger if no
other loggers are defined in the initialization section. 

The C<error()>
method fires up a message, which the root logger catches. Its
priority is equal to
or higher than the root logger's priority (ERROR), which causes the root logger
to forward it to its attached appender. By contrast, the following

    $logger->warn("Oh my, a dreadful warning!");

doesn't make it through, because the root logger sports a higher setting
(ERROR and up) than the WARN priority of the message.

=head2 How can I install Log::Log4perl on Microsoft Windows?

Log::Log4perl is fully supported on the Win32 platform. It has been tested 
with Activestate perl 5.6.1 under Windows 98 and rumor has it that it
also runs smoothly on all other major flavors (Windows NT, 2000, XP, etc.).

It also runs nicely with the buggy ActiveState 5.8.0 beta as of this
writing, and, believe me, we had to jump through some major hoops for that.

Typically, Win32 systems don't have the C<make> utility installed,
so the standard C<perl Makefile.PL; make install> on the downloadable
distribution won't work. But don't despair, there's a very easy solution!

The C<Log::Log4perl> homepage provides a so-called PPD file for ActiveState's
C<ppm> installer, which comes with ActiveState perl by default.

=over 4

=item Install on ActiveState 5.6.*

The DOS command line

    ppm install "http://log4perl.sourceforge.net/ppm/Log-Log4perl.ppd"

will contact the Log4perl homepage, download the latest
C<Log::Log4perl>
distribution and install it. If your ActiveState installation
lacks any of the modules C<Log::Log4perl> depends upon, C<ppm> will 
automatically contact ActivateState and download them from their CPAN-like
repository.

=item Install on ActiveState 5.8.*

ActiveState's "Programmer's Package Manager" can be called from
Window's Start Menu:
Start-E<gt>Programs->E<gt>ActiveState ActivePerl 5.8E<gt>Perl Package Manager
will invoke ppm. Since Log::Log4perl hasn't made it yet into the standard
ActiveState repository (and you probably don't want their outdated packages
anyway), just tell ppm the first time you call it to add the Log4perl 
repository

    ppm> repository add http://log4perl.sourceforge.net/ppm

Then, just tell it to install Log::Log4perl and it will resolve all
dependencies automatically and fetch them from log4perl.sourceforge.net
if it can't find them in the main archives:

    ppm> install Log::Log4perl

=back

That's it! Afterwards, just create a Perl script like

    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($DEBUG);

    my $logger = get_logger("Twix::Bar");
    $logger->debug("Watch me!");

and run it. It should print something like 

    2002/11/06 01:22:05 Watch me!

If you find that something doesn't work, please let us know at
log4perl-devel@lists.sourceforge.net -- we'll apprechiate it. Have fun!

=head2 What's the easiest way to use Log4perl?

If you just want to get all the comfort of logging, without much
overhead, use I<Stealth Loggers>. If you use Log::Log4perl in 
C<:easy> mode like

    use Log::Log4perl qw(:easy);

you'll have the following functions available in the current package:

    DEBUG("message");
    INFO("message");
    WARN("message");
    ERROR("message");
    FATAL("message");

Just make sure that every package of your code where you're using them in
pulls in C<use Log::Log4perl qw(:easy)> first, then you're set.
Every stealth logger's category will be equivalent to the name of the
package it's located in.

These stealth loggers
will be absolutely silent until you initialize Log::Log4perl in 
your main program with either 

        # Define any Log4perl behaviour
    Log::Log4perl->init("foo.conf");

(using a full-blown Log4perl config file) or the super-easy method

        # Just log to STDERR
    Log::Log4perl->easy_init($DEBUG);

or the parameter-style method with a complexity somewhat in between:

        # Append to a log file
    Log::Log4perl->easy_init( { level   => $DEBUG,
                                file    => ">>test.log" } );

For more info, please check out L<Log::Log4perl/"Stealth Loggers">.

=head2 How can I include global (thread-specific) data in my log messages?

Say, you're writing a web application and want all your
log messages to include the current client's IP address. Most certainly,
you don't want to include it in each and every log message like in

    $logger->debug( $r->connection->remote_ip,
                    " Retrieving user data from DB" );

do you? Instead, you want to set it in a global data structure and
have Log::Log4perl include it automatically via a PatternLayout setting
in the configuration file:

    log4perl.appender.FileApp.layout.ConversionPattern = %X{ip} %m%n

The conversion specifier C<%X{ip}> references an entry under the key
C<ip> in the global C<MDC> (mapped diagnostic context) table, which 
you've set once via

    Log::Log4perl::MDC->put("ip", $r->connection->remote_ip);

at the start of the request handler. Note that this is a
I<static> (class) method, there's no logger object involved.
You can use this method with as many key/value pairs as you like as long
as you reference them under different names.

The mappings are stored in a global hash table within Log::Log4perl.
Luckily, because the thread
model in 5.8.0 doesn't share global variables between threads unless
they're explicitly marked as such, there's no problem with multi-threaded
environments.

For more details on the MDC, please refer to 
L<Log::Log4perl/"Mapped Diagnostic Context (MDC)"> and
L<Log::Log4perl::MDC>.

=head2 My application is already logging to a file. How can I duplicate all messages to also go to the screen?

Assuming that you already have a Log4perl configuration file like

    log4perl.logger                    = DEBUG, FileApp

    log4perl.appender.FileApp          = Log::Dispatch::File
    log4perl.appender.FileApp.filename = test.log
    log4perl.appender.FileApp.layout   = PatternLayout
    log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n

and log statements all over your code,
it's very easy with Log4perl to have the same messages both printed to
the logfile and the screen. No reason to change your code, of course, 
just add another appender to the configuration file and you're done:

    log4perl.logger                    = DEBUG, FileApp, ScreenApp

    log4perl.appender.FileApp          = Log::Dispatch::File
    log4perl.appender.FileApp.filename = test.log
    log4perl.appender.FileApp.layout   = PatternLayout
    log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n

    log4perl.appender.ScreenApp          = Log::Dispatch::Screen
    log4perl.appender.ScreenApp.stderr   = 0
    log4perl.appender.ScreenApp.layout   = PatternLayout
    log4perl.appender.ScreenApp.layout.ConversionPattern = %d> %m%n

The configuration file above is assuming that both appenders are
active in the same logger hierarchy, in this case the C<root> category.
But even if you've got file loggers defined in several parts of your system,
belonging to different logger categories,
each logging to different files, you can gobble up all logged messages
by defining a root logger with a screen appender, which would duplicate 
messages from all your file loggers to the screen due to Log4perl's 
appender inheritance. Check 

    http://www.perl.com/pub/a/2002/09/11/log4perl.html

for details. Have fun!

=head2 How can I make sure my application logs a message when it dies unexpectedly?

Whenever you encounter a fatal error in your application, instead of saying
something like

    open FILE, "<blah" or die "Can't open blah -- bailing out!";
    
just use Log::Log4perl's fatal functions instead:

    my $log = get_logger("Some::Package");
    open FILE, "<blah" or $log->logdie("Can't open blah -- bailing out!");

This will both log the message with priority FATAL according to your current
Log::Log4perl configuration and then call Perl's C<die()> 
afterwards to terminate the program. It works the same with 
stealth loggers (see L<Log::Log4perl/"Stealth Loggers">), 
all you need to do is call

    use Log::Log4perl qw(:easy);
    open FILE, "<blah" or LOGDIE "Can't open blah -- bailing out!";

What can you do if you're using some library which doesn't use Log::Log4perl
and calls C<die()> internally if something goes wrong? Use a
C<$SIG{__DIE__}> pseudo signal handler

    use Log::Log4perl qw(get_logger);

    $SIG{__DIE__} = sub {
        $Log::Log4perl::caller_depth++;
        my $logger = get_logger("");
        $logger->fatal(@_);
        exit 1;
    };

This will catch every C<die()>-Exception of your
application or the modules it uses. It
will fetch a root logger and pass on the C<die()>-Message to it.
If you make sure you've configured with a root logger like this:

    Log::Log4perl->init(\q{
        log4perl.category         = FATAL, Logfile
        log4perl.appender.Logfile = Log::Dispatch::File
        log4perl.appender.Logfile.filename = fatal_errors.log
        log4perl.appender.Logfile.layout = \
                   Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = %F{1}-%L (%M)> %m%n
    });

then all C<die()> messages will be routed to a file properly. The line

     $Log::Log4perl::caller_depth++;

in the pseudo signal handler above merits a more detailed explanation. With
the setup above, if a module calls C<die()> in one of its functions, 
the fatal message will be logged in the signal handler and not in the
original function -- which will cause the %F, %L and %M placeholders
in the pattern layout to be replaced by the filename, the line number
and the function/method name of the signal handler, not the error-throwing
module. To adjust this, Log::Log4perl has the C<$caller_depth> variable, 
which defaults to 0, but can be set to positive integer values
to offset the caller level. Increasing
it by one will cause it to log the calling function's parameters, not
the ones of the signal handler. 
See L<Log::Log4perl/"Using Log::Log4perl from wrapper classes"> for more
details.

=cut

=head1 SEE ALSO

Log::Log4perl

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>

=cut
