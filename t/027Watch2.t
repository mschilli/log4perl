#testing init_and_watch
#special problem with init_and_watch,
#fixed in Logger::reset by setting logger level to OFF

use Test;

use warnings;
use strict;

use Log::Log4perl;

my $testconf= 't/tmp/test27.conf';
unlink $testconf if (-e $testconf);

$
 Log::Log4perl::TestBuffer::POPULATION = undef;  #for warnings



my $conf1 = <<EOL;
log4j.category   = WARN, myAppender

log4j.appender.myAppender          = Log::Log4perl::TestBuffer
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.dog = DEBUG, goneAppender

log4j.appender.goneAppender          = Log::Log4perl::TestBuffer
log4j.appender.goneAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.cat = INFO, myAppender

EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf1;
close CONF;


Log::Log4perl->init_and_watch($testconf, 1);

my $logger = Log::Log4perl::get_logger('animal.dog');

my $app0 = $   #cvs fodder
        Log::Log4perl::TestBuffer::POPULATION[0];

$logger->debug('debug message, should appear');

ok($app0->buffer(), "DEBUG - debug message, should appear\n");


#---------------------------
#now go to sleep and reload

print "sleeping for 3 seconds\n";
sleep 3;

$conf1 = <<EOL;
log4j.category   = WARN, myAppender

log4j.appender.myAppender          = Log::Log4perl::TestBuffer
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout

#*****log4j.category.animal.dog = DEBUG, goneAppender

#*****log4j.appender.goneAppender          = Log::Log4perl::TestBuffer
#*****log4j.appender.goneAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.cat = INFO, myAppender

EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf1;
close CONF;


#now the logger is ruled by root's WARN level
$logger->debug('debug message, should NOT appear');

my $app1 = $   #cvs fodder
        Log::Log4perl::TestBuffer::POPULATION[$#Log::Log4perl::TestBuffer::POPULATION];

ok($app1->buffer(), "");

$logger->warn('warning message, should appear');

ok($app1->buffer(), "WARN - warning message, should appear\n");

#check the root logger
$logger = Log::Log4perl::get_logger();

$logger->warn('warning message, should appear');

ok($app1->buffer(), "/(WARN - warning message, should appear\n){2}/");

# -------------------------------------------
#double-check an unrelated category with a lower level
$logger = Log::Log4perl::get_logger('animal.cat');
$logger->info('warning message to cat, should appear');

ok($app1->buffer(), "/(WARN - warning message, should appear\n){2}INFO - warning message to cat, should appear/");


BEGIN {plan tests => 5};
unlink $testconf;
