BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Log::Log4perl;
use Test;

our $LOG_DISPATCH_PRESENT = 0;

BEGIN { 
    eval { require Log::Dispatch; };
    if($@) {
       plan skip_all => "only with Log::Dispatch";
    } elsif (!$ENV{LOG_DISPATCH_TEST_EMAIL}) {
       skip ("Log::Log4perl::JavaMap::SMTPAppender test (env variable LOG_DISPATCH_TEST_EMAIL is not defined)");
    } else {
       $LOG_DISPATCH_PRESENT = 1;
       plan tests => 1;
    }
};

my %TestConfig;
if (my $email_address = $ENV{LOG_DISPATCH_TEST_EMAIL}) {
    %TestConfig = ( email_address => $email_address );
}


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

eval {

   Log::Log4perl->init(\$conf);

   my $logger = Log::Log4perl->get_logger('cat1');

   $logger->debug("debugging message 1 ");
   $logger->info("info message 1 ");      
   $logger->warn("warning message 1 ");   

};

ok(1);


