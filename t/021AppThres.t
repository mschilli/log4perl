###########################################
# Test Suite for Log::Log4perl::Logger
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test;

use Log::Log4perl qw(get_logger);
use Log::Log4perl::Level;

BEGIN { plan tests => 9 }

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

##################################################
# Appender threshold with config file
##################################################
# Reset appender population
@Log::Log4perl::TestBuffer::POPULATION = ();

my $conf = <<EOT;
log4perl.logger   = ERROR, BUF0
log4perl.logger.a = INFO, BUF1
log4perl.appender.BUF0           = Log::Log4perl::TestBuffer
log4perl.appender.BUF0.layout    = Log::Log4perl::Layout::SimpleLayout
log4perl.appender.BUF0.Threshold = ERROR
log4perl.appender.BUF1           = Log::Log4perl::TestBuffer
log4perl.appender.BUF1.layout    = Log::Log4perl::Layout::SimpleLayout
log4perl.appender.BUF1.Threshold = WARN
EOT

Log::Log4perl::init(\$conf);

    # Sorry 'bout that, but CVS is too stupid to grok that that's not a macro
$app0 = $
        Log::Log4perl::TestBuffer::POPULATION[0];
$app1 = $
        Log::Log4perl::TestBuffer::POPULATION[1];

my $loga = get_logger("a");

$loga->info("Don't want to see this");
$loga->error("Yeah, loga");

ok($app0->buffer(), "ERROR - Yeah, loga\n");
ok($app1->buffer(), "ERROR - Yeah, loga\n");
