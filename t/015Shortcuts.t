###########################################
# Test Suite for Log::Log4perl
# Test all shortcuts (exported symbols)
#
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 6 };

use Log::Log4perl qw(:shortcuts);
use Log::Log4perl::Level;

ok(1);

##################################################
# Init logger
##################################################
my $app = Log::Log4perl::Appender->new(
    "Log::Dispatch::Buffer");
my $logger = Log::Log4perl->get_logger("main");
$logger->add_appender($app);
$logger->level($DEBUG);

##################################################
# Test shortcuts
##################################################
debug("Debug message");
ok($app->buffer(), "DEBUG - Debug message");
$app->buffer("");

warn("Warn message");
ok($app->buffer(), "WARN - Warn message");
$app->buffer("");

info("Info message");
ok($app->buffer(), "INFO - Info message");
$app->buffer("");

error("Error message");
ok($app->buffer(), "ERROR - Error message");
$app->buffer("");

fatal("Fatal message");
ok($app->buffer(), "FATAL - Fatal message");
$app->buffer("");
