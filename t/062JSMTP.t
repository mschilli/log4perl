BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Log::Log4perl;
use Test::More;

BEGIN {
    eval { require Log::Dispatch::Email::MailSender; };
    if($@) {
       plan skip_all => "only with Log::Dispatch::Email::MailSender";
    } else {
       plan tests => 3;
    }
};

my %TestConfig;
SKIP: {

my $email_address = $ENV{SMTPAPPENDER_TEST_EMAIL};
skip "Log::Log4perl::JavaMap::SMTPAppender test (env variable SMTPAPPENDER_TEST_EMAIL is not defined)", 3 unless $email_address;

%TestConfig = ( email_address => $email_address );

print <<EOL;
Sending email to $TestConfig{email_address}.
If you get these messages, then the test succeeded:

INFO - info message 1
WARN - warning message 1

EOL

my $conf = <<CONF;
log4j.category.cat1      = INFO, myAppender

log4j.appender.myAppender=org.apache.log4j.SMTPAppender
log4j.appender.myAppender.layout=org.apache.log4j.SimpleLayout
log4j.appender.myAppender.to=$TestConfig{email_address}
CONF

Log::Log4perl->init(\$conf);
my $logger = Log::Log4perl->get_logger('cat1');

ok($logger->debug('debugging message 1'), 'debugging message');
ok($logger->info('info message 1'), 'info message');
ok($logger->warn('warning message 1'), 'warning message');

};

