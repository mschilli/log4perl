#testing init_and_watch

use Test;

use Log::Log4perl;

$testfile = 't/tmp/test17.log';
unlink $testfile if (-e $testfile);

$testconf= 't/tmp/test17.conf';
unlink $testconf if (-e $testconf);



$conf1 = <<EOL;
log4j.category.animal.dog   = INFO, myAppender

log4j.appender.myAppender          = Log::Dispatch::File
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.filename = $testfile
log4j.appender.myAppender.mode     = append

EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf1;
close CONF;


Log::Log4perl->init_and_watch($testconf, 2);

$logger = Log::Log4perl::get_logger('animal.dog');

$logger->debug('debug message');
$logger->info('info message');


# ***************************************************************
# do it again

print "sleeping for 3 secs\n";
sleep 3;

$conf2 = <<EOL;
log4j.category.animal.dog   = DEBUG, myAppender

log4j.appender.myAppender          = Log::Dispatch::File
log4j.appender.myAppender.layout = org.apache.log4j.PatternLayout
log4j.appender.myAppender.layout.ConversionPattern=%-5p %c %x - %m%n

log4j.appender.myAppender.filename = $testfile
log4j.appender.myAppender.mode     = append
EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf2;
close CONF;

$logger = Log::Log4perl::get_logger('animal.dog');

$logger->debug('2nd debug message');
$logger->info('2nd info message');


open (LOG, $testfile) or die "can't open $testfile $!";
@log = <LOG>;
close LOG;
$log = join('',@log);

ok($log, "INFO - info message\nDEBUG animal.dog N/A - 2nd debug message\nINFO  animal.dog N/A - 2nd info message\n");


# ***************************************************************
# do it 3rd time

print "sleeping for 3 secs\n";
sleep 3;

$conf2 = <<EOL;
$conf1 = <<EOL;
log4j.category.animal.dog   = INFO, myAppender

log4j.appender.myAppender          = Log::Dispatch::File
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.filename = $testfile
log4j.appender.myAppender.mode     = append
EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf2;
close CONF;

$logger = Log::Log4perl::get_logger('animal.dog');

$logger->debug('2nd debug message');
$logger->info('3rd info message');


open (LOG, $testfile) or die "can't open $testfile $!";
@log = <LOG>;
close LOG;
$log = join('',@log);

ok($log, "INFO - info message\nDEBUG animal.dog N/A - 2nd debug message\nINFO  animal.dog N/A - 2nd info message\nINFO - 3rd info message\n");


BEGIN {plan tests => 2};

unlink $testfile if (-e $testfile);
unlink $testconf if (-e $testconf);
