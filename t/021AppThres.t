###########################################
# Test Suite for Log::Log4perl::Logger
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test;

use Log::Log4perl;
use Log::Log4perl::Level;

BEGIN { plan tests => 7 }

ok(1); # If we made it this far, we're ok.

my $log0 =  Log::Log4perl->get_logger("");
my $log1 = Log::Log4perl->get_logger("abc.def");
my $log2 = Log::Log4perl->get_logger("abc.def.ghi");

$log0->level($DEBUG);
$log1->level($DEBUG);
$log2->level($DEBUG);

my $app0 = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

my $app1 = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

$app0->threshold($ERROR);
$app1->threshold($WARN);

$log0->add_appender($app0);
$log1->add_appender($app1);

##################################################
# Root logger's appender
##################################################
$app0->buffer("");
$app1->buffer("");
$log0->warn("Don't want to see this");
$log0->error("Yeah, log0");

ok($app0->buffer(), "ERROR - Yeah, log0\n");
ok($app1->buffer(), "");

##################################################
# Inherited appender
##################################################
$app0->buffer("");
$app1->buffer("");
$log1->info("Don't want to see this");
$log1->warn("Yeah, log1");

ok($app0->buffer(), "");
ok($app1->buffer(), "WARN - Yeah, log1\n");

##################################################
# Inherited appender over two hierarchies
##################################################
$app0->buffer("");
$app1->buffer("");
$log2->info("Don't want to see this");
$log2->error("Yeah, log2");

ok($app0->buffer(), "ERROR - Yeah, log2\n");
ok($app1->buffer(), "ERROR - Yeah, log2\n");
