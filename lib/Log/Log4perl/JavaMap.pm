package Log::Log4perl::JavaMap;

use Carp;
use strict;

our %translate = (
    'org.apache.log4j.ConsoleAppender' => 
        'Log::Log4perl::JavaMap::ConsoleAppender',
    'org.apache.log4j.FileAppender'    => 
        'Log::Log4perl::JavaMap::FileAppender',
);

sub get {
    my ($appender_name, $appender_data) = @_;
    #appender_name is the user name like 'myAppender'
    #appender_data will be a hashref that looks like this:
    #    {
    #      File   => { value => "t/tmp/test1.log" },
    #      layout => {
    #                  ConversionPattern => 
    #                                  { value => "%r [%t] %-5p %c %x - %m%n" },
    #                  value => "org.apache.log4j.PatternLayout",
    #                },
    #      value  => "org.apache.log4j.ConsoleAppender",
    #    },

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

Here's the list of appenders I see on the current (6/2002) log4j site.

These are implemented

    ConsoleAppender - Log::Dispatch::Screen
    FileAppender    - Log::Dispatch::File


These should/will/might be implemented

    RollingFileAppender - 
    DailyRollingFileAppender - 
    SMTPAppender     - Log::Dispatch::Email::MailSender
    SyslogAppender - Log::Dispatch::Syslog
    SocketAppender - (pass a socket to Log::Dispatch)
    JDBCAppender - Log::Dispatch::DBI
    

These might be implemented but they don't have corresponding classes
in Log::Dispatch (yet):

    NullAppender
    NTEventLogAppender
    TelnetAppender

These might be simulated

    LF5Appender - use Tk?
    ExternallyRolledFileAppender - catch a HUP instead?

These will probably not be implemented

    AsyncAppender
    JMSAppender
    SocketHubAppender


=head1 AUTHORS

    Kevin Goess, <cpan@goess.org> 
    Mike Schilli, <m@perlmeister.com>
    
    June, 2002

=head1 SEE ALSO

http://jakarta.apache.org/log4j/docs/

=cut
