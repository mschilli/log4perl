###########################################
# Test Suite for Log::Log4perl::Logger
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 29 };

use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Dispatch::Buffer;

ok(1); # If we made it this far, we're ok.

my $log1 = Log::Log4perl::Logger->get_logger("abc.def");
my $log2 = Log::Log4perl::Logger->get_logger("abc.def");
my $log3 = Log::Log4perl::Logger->get_logger("abc.def.ghi");
my $log4 = Log::Log4perl::Logger->get_logger("def.abc.def");
my $log5 = Log::Log4perl::Logger->get_logger("def.abc.def");
my $log6 = Log::Log4perl::Logger->get_logger("");
my $log7 = Log::Log4perl::Logger->get_logger("");
my $log8 = Log::Log4perl::Logger->get_logger("abc.def");
my $log9 = Log::Log4perl::Logger->get_logger("abc::def::ghi");

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

my $disp = Log::Dispatch::Buffer->new(
    min_level => "debug",
    name      => "buf",
);

##################################################
# Suppress debug
##################################################
$log1->add_appender($disp);
$log1->level($ERROR);
$log1->error("Error Message");
$log1->debug("Debug Message");
ok($disp->buffer(), "Error Message");

##################################################
# Allow debug
##################################################
$log1->level($DEBUG);
$disp->buffer("");
$log1->error("Error Message");
$log1->debug("Debug Message");
ok($disp->buffer(), "Error MessageDebug Message");

##################################################
# Multiple Appenders
##################################################
my $disp2 = Log::Dispatch::Buffer->new(
    min_level => "debug",
    name      => "buf2",
);
my $disp3 = Log::Dispatch::Buffer->new(
    min_level => "debug",
    name      => "buf3",
);

$disp->buffer("");
$disp2->buffer("");
    # 2nd appender to $log1
$log1->add_appender($disp2);
$log1->level($ERROR);
$log1->error("Error Message");
ok($disp->buffer(), "Error Message");
ok($disp2->buffer(), "Error Message");

##################################################
# Multiple Appenders in different hierarchy levels
##################################################
$disp->buffer("");
$disp2->buffer("");
$disp3->buffer("");

$log1 = Log::Log4perl::Logger->get_logger("xxx.yyy.zzz");
$log2 = Log::Log4perl::Logger->get_logger("xxx");
$log3 = Log::Log4perl::Logger->get_logger("");

    # Root logger
$log3->add_appender($disp3);
$log3->level($ERROR);

    ##################################################
    # Log to lower level, check if gets propagated up to root
    ##################################################
$log1->error("Error Message");
    # Should be distributed to root
ok($disp3->buffer(), "Error Message");

    ##################################################
    # Log in lower levels and propagate to root
    ##################################################
$disp->buffer("");
$disp2->buffer("");
$disp3->buffer("");

$log1->add_appender($disp);
$log2->add_appender($disp2);
# log3 already has disp3 attached
$log1->error("Error Message");
ok($disp->buffer(), "Error Message");
ok($disp2->buffer(), "Error Message");
ok($disp3->buffer(), "Error Message");

    ##################################################
    # Block appenders via priority 
    ##################################################
$disp->buffer("");
$disp2->buffer("");
$disp3->buffer("");

$log1->level($ERROR);
$log2->level($DEBUG);
$log3->level($DEBUG);

$log1->debug("Debug Message");
ok($disp->buffer(), "");
ok($disp2->buffer(), "");
ok($disp3->buffer(), "");

    ##################################################
    # Block via 'false' additivity
    ##################################################
$disp->buffer("");
$disp2->buffer("");
$disp3->buffer("");

$log1->level($DEBUG);
$log2->additivity(0);
$log2->level($DEBUG);
$log3->level($DEBUG);

$log1->debug("Debug Message");
ok($disp->buffer(), "Debug Message");
ok($disp2->buffer(), "Debug Message");
ok($disp3->buffer(), "");
