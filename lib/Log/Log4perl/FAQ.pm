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

=head1 SEE ALSO

Log::Log4perl

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>

=cut
