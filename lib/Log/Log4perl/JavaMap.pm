package Log::Log4perl::JavaMap;

use Carp;
use strict;

use constant DEBUG => 0;

our %translate = (
    'org.apache.log4j.ConsoleAppender' => 
        'Log::Log4perl::JavaMap::ConsoleAppender',
    'org.apache.log4j.FileAppender'    => 
        'Log::Log4perl::JavaMap::FileAppender',
    'org.apache.log4j.RollingFileAppender'    => 
        'Log::Log4perl::JavaMap::RollingFileAppender',
    'org.apache.log4j.TestBuffer'    => 
        'Log::Log4perl::JavaMap::TestBuffer',
     'org.apache.log4j.jdbc.JDBCAppender'    => 
        'Log::Log4perl::JavaMap::JDBCAppender',
     'org.apache.log4j.SyslogAppender'    => 
        'Log::Log4perl::JavaMap::SyslogAppender',
     'org.apache.log4j.NTEventLogAppender'    => 
        'Log::Log4perl::JavaMap::NTEventLogAppender',
);

sub get {
    my ($appender_name, $appender_data) = @_;

    print "Trying to map $appender_name\n" if DEBUG;

    $appender_data->{value} ||
            die "ERROR: you didn't tell me how to implement your appender " .
                "'$appender_name'";

    my $perl_class = $translate{$appender_data->{value}} || 
            die "ERROR:  I don't know how to make a '$appender_data->{value}' " .
                "to implement your appender '$appender_name', that's not a " .
                "supported class\n";
    eval {
        eval "require $perl_class";  #see 'perldoc -f require' for why two evals
        die $@ if $@;
    };
    $@ and die "ERROR: trying to set appender for $appender_name to " .
               "$appender_data->{value} using $perl_class failed\n$@  \n";

    my $app = $perl_class->new($appender_name, $appender_data);
    return $app;
}

1;


=head1 NAME

Log::Log4perl::JavaMap - maps java log4j appenders to Log::Dispatch classes

=head1 SYNOPSIS

     ###############################
     log4j.appender.FileAppndr1        = org.apache.log4j.FileAppender
     log4j.appender.FileAppndr1.File   = /var/log/onetime.log
     log4j.appender.FileAppndr1.Append = false

     log4j.appender.FileAppndr1.layout = org.apache.log4j.PatternLayout
     log4j.appender.FileAppndr1.layout.ConversionPattern=%d %4r [%t] %-5p %c %x - %m%n
     ###############################


=head1 DESCRIPTION

If somebody wants to create an appender called C<org.apache.log4j.ConsoleAppender>,
we want to translate it to Log::Dispatch::Screen, and then translate
the log4j options into Log::Dispatch parameters..

=head2 What's Implemented

(Note that you can always use the Log::Dispatch::* module.  By 'implemented'
I mean having a translation class that translates log4j options into
the Log::Dispatch options so you can use log4j rather than log4perl 
syntax in your config file.)

Here's the list of appenders I see on the current (6/2002) log4j site.

These are implemented

    ConsoleAppender     - Log::Dispatch::Screen
    FileAppender        - Log::Dispatch::File
    RollingFileAppender - Log::Dispatch::FileRotate (by Mark Pfeiffer)
    JDBCAppender        - Log::Log4perl::Appender::DBI
    SyslogAppender      - Log::Dispatch::Syslog
    NTEventLogAppender  - Log::Dispatch::Win32EventLog


These should/will/might be implemented
    
    DailyRollingFileAppender - 
    SMTPAppender     - Log::Dispatch::Email::MailSender
    

These might be implemented but they don't have corresponding classes
in Log::Dispatch (yet):

    NullAppender
    TelnetAppender

These might be simulated

    LF5Appender - use Tk?
    ExternallyRolledFileAppender - catch a HUP instead?

These will probably not be implemented

    AsyncAppender
    JMSAppender
    SocketAppender - (ships a serialized LoggingEvent to the server side)
    SocketHubAppender


=head1 AUTHORS

    Kevin Goess, <cpan@goess.org> 
    Mike Schilli, <m@perlmeister.com>
    
    June, 2002

=head1 SEE ALSO

http://jakarta.apache.org/log4j/docs/

=cut
