###########################################
# Test Suite for Log::Log4perl::Logger
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;


use Log::Log4perl;
use Log::Log4perl::Level;

ok(1); # If we made it this far, we're ok.

my $log1 = Log::Log4perl->get_logger("abc.def");
my $log2 = Log::Log4perl->get_logger("abc.def");
my $log3 = Log::Log4perl->get_logger("abc.def.ghi");
my $log4 = Log::Log4perl->get_logger("def.abc.def");
my $log5 = Log::Log4perl->get_logger("def.abc.def");
my $log6 = Log::Log4perl->get_logger("");
my $log7 = Log::Log4perl->get_logger("");
my $log8 = Log::Log4perl->get_logger("abc.def");
my $log9 = Log::Log4perl->get_logger("abc::def::ghi");

# Loggers for the same namespace have to be identical
ok($log1 == $log2);
ok($log4 == $log5);
ok($log6 == $log7);
ok($log1 == $log8);
ok($log3 == $log9);

# Loggers for different namespaces have to be different
ok($log1 != $log3);
ok($log3 != $log4);
ok($log1 != $log6);
ok($log3 != $log6);
ok($log5 != $log6);
ok($log5 != $log7);
ok($log5 != $log1);
ok($log7 != $log8);
ok($log8 != $log9);

my $app = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

##################################################
# Suppress debug
##################################################
$log1->add_appender($app);
$log1->level($ERROR);
$log1->error("Error Message");
$log1->debug("Debug Message");
ok($app->buffer(), "ERROR - Error Message");

##################################################
# Allow debug
##################################################
$log1->level($DEBUG);
$app->buffer("");
$log1->error("Error Message");
$log1->debug("Debug Message");
ok($app->buffer(), "ERROR - Error MessageDEBUG - Debug Message");

##################################################
# Multiple Appenders
##################################################
my $app2 = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");
my $app3 = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

$app->buffer("");
$app2->buffer("");
    # 2nd appender to $log1
$log1->add_appender($app2);
$log1->level($ERROR);
$log1->error("Error Message");
#TODO
ok($app->buffer(), "ERROR - Error Message");
ok($app2->buffer(), "ERROR - Error Message");

##################################################
# Multiple Appenders in different hierarchy levels
##################################################
$app->buffer("");
$app2->buffer("");
$app3->buffer("");

$log1 = Log::Log4perl->get_logger("xxx.yyy.zzz");
$log2 = Log::Log4perl->get_logger("xxx");
$log3 = Log::Log4perl->get_logger("");

    # Root logger
$log3->add_appender($app3);
$log3->level($ERROR);

    ##################################################
    # Log to lower level, check if gets propagated up to root
    ##################################################
$log1->error("Error Message");
    # Should be distributed to root
ok($app3->buffer(), "ERROR - Error Message");

    ##################################################
    # Log in lower levels and propagate to root
    ##################################################
$app->buffer("");
$app2->buffer("");
$app3->buffer("");

$log1->add_appender($app);
$log2->add_appender($app2);
# log3 already has app3 attached
$log1->error("Error Message");
ok($app->buffer(), "ERROR - Error Message");
ok($app2->buffer(), "ERROR - Error Message");
ok($app3->buffer(), "ERROR - Error Message");

    ##################################################
    # Block appenders via priority 
    ##################################################
$app->buffer("");
$app2->buffer("");
$app3->buffer("");

$log1->level($ERROR);
$log2->level($DEBUG);
$log3->level($DEBUG);

$log1->debug("Debug Message");
ok($app->buffer(), "");
ok($app2->buffer(), "");
ok($app3->buffer(), "");

    ##################################################
    # Block via 'false' additivity
    ##################################################
$app->buffer("");
$app2->buffer("");
$app3->buffer("");

$log1->level($DEBUG);
$log2->additivity(0);
$log2->level($DEBUG);
$log3->level($DEBUG);

$log1->debug("Debug Message");
ok($app->buffer(), "DEBUG - Debug Message");
ok($app2->buffer(), "DEBUG - Debug Message");
ok($app3->buffer(), "");

    ##################################################
    # Check is_*() functions
    ##################################################
$log1->level($DEBUG);
$log2->level($ERROR);
$log3->level($INFO);

ok($log1->is_error(), 1);
ok($log1->is_info(), 1);
ok($log1->is_fatal(), 1);
ok($log1->is_debug(), 1);

ok($log2->is_error(), 1);
ok($log2->is_info(), "");
ok($log2->is_fatal(), 1);
ok($log2->is_debug(), "");

ok($log3->is_error(), 1);
ok($log3->is_info(), 1);
ok($log3->is_fatal(), 1);
ok($log3->is_debug(), "");


    ##################################################
    # Check log->(<level_const>,<msg>)
    ##################################################
$app->buffer("");
$app2->buffer("");
$app3->buffer("");

$log1->level($DEBUG);
$log2->level($ERROR);
$log3->level($INFO);

$log1->log($DEBUG, "debug message");
$log1->log($INFO,  "info message ");

$log2->log($DEBUG, "debug message");
$log2->log($INFO,  "info message ");

$log3->log($DEBUG, "debug message");
$log3->log($INFO,  "info message ");

ok($app->buffer(), 'DEBUG - debug messageINFO - info message ');
ok($app2->buffer(),'DEBUG - debug messageINFO - info message ');
ok($app3->buffer(),'INFO - info message ');


BEGIN { plan tests => 44 };
