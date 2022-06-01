#testing init_and_watch
#same as 027Watch2, just with signal handling instead of watch/delay code

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use strict;
use warnings;
use Test::More;
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir need_signals);

BEGIN {
    need_signals();
}

use Log::Log4perl;
use Log::Log4perl::Appender::TestBuffer;
use File::Spec;

my $WORK_DIR = tmpdir();
my $testconf= File::Spec->catfile($WORK_DIR, "test27.conf");

Log::Log4perl::Appender::TestBuffer->reset();

my $conf1 = <<EOL;
log4j.category   = WARN, myAppender

log4j.appender.myAppender          = Log::Log4perl::Appender::TestBuffer
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.dog = DEBUG, goneAppender

log4j.appender.goneAppender          = Log::Log4perl::Appender::TestBuffer
log4j.appender.goneAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.cat = INFO, myAppender

EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf1;
close CONF;

Log::Log4perl->init_and_watch($testconf, 'HUP');

my $logger = Log::Log4perl::get_logger('animal.dog');

ok(  $logger->is_debug(), "is_debug - true");
ok(  $logger->is_info(),  "is_info - true");
ok(  $logger->is_warn(),  "is_warn - true");
ok(  $logger->is_error(), "is_error - true");
ok(  $logger->is_fatal(), "is_fatal - true");

my $app0 = Log::Log4perl::Appender::TestBuffer->by_name("myAppender");

$logger->debug('debug message, should appear');

is($app0->buffer(), "DEBUG - debug message, should appear\n", "debug()");


#---------------------------
#now reload and then signal

$conf1 = <<EOL;
log4j.category   = WARN, myAppender

log4j.appender.myAppender          = Log::Log4perl::Appender::TestBuffer
log4j.appender.myAppender.layout   = Log::Log4perl::Layout::SimpleLayout

#*****log4j.category.animal.dog = DEBUG, goneAppender

#*****log4j.appender.goneAppender          = Log::Log4perl::Appender::TestBuffer
#*****log4j.appender.goneAppender.layout   = Log::Log4perl::Layout::SimpleLayout

log4j.category.animal.cat = INFO, myAppender

EOL
open (CONF, ">$testconf") || die "can't open $testconf $!";
print CONF $conf1;
close CONF;

#---------------------------
# send the signal to the process itself
kill(1, $$) or die "Cannot signal";

ok(! $logger->is_debug(), "is_debug - false");
ok(! $logger->is_info(),  "is_info - false");
ok(  $logger->is_warn(),  "is_warn - true");
ok(  $logger->is_error(), "is_error - true");
ok(  $logger->is_fatal(), "is_fatal - true");

#now the logger is ruled by root's WARN level
$logger->debug('debug message, should NOT appear');

my $app1 = Log::Log4perl::Appender::TestBuffer->by_name("myAppender");

is($app1->buffer(), "", "buffer empty");

$logger->warn('warning message, should appear');

is($app1->buffer(), "WARN - warning message, should appear\n", "warn in");

#check the root logger
$logger = Log::Log4perl::get_logger();

$logger->warn('warning message, should appear');

like($app1->buffer(), qr/(WARN - warning message, should appear\n){2}/,
     "2nd warn in");

# -------------------------------------------
#double-check an unrelated category with a lower level
$logger = Log::Log4perl::get_logger('animal.cat');
$logger->info('warning message to cat, should appear');

like($app1->buffer(), qr/(WARN - warning message, should appear\n){2}INFO - warning message to cat, should appear/, "message output");

done_testing;
