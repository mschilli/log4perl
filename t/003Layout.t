###########################################
# Test Suite for Log::Log4perl
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 9 };

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Log4perl::TestBuffer;

my $app = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

ok(1); # If we made it this far, we're ok.

my $logger = Log::Log4perl->get_logger("abc.def.ghi");
$logger->add_appender($app);
my $layout = Log::Log4perl::Layout::PatternLayout->new(
    "bugo %% %c{2} %-17F{2} %L hugo");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), "bugo % def.ghi t/003Layout.t     31 hugo"); 

############################################################
# Log the message
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new(
   "The message is here: %m");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), "The message is here: That's the message"); 

############################################################
# Log the time
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("[%r] %m");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer() =~ /^\[\d+\] That's the message$/); 

############################################################
# Log the date/time
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%d> %m");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), 
   'm#^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d> That\'s the message$#'); 

############################################################
# Check SimpleLayout
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::SimpleLayout->new();
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), "DEBUG - That\'s the message\n"); 

############################################################
# Check depth level of %M - with debug(...)
############################################################

sub mysubroutine {
    $app->buffer("");
    $layout = Log::Log4perl::Layout::PatternLayout->new("%M: %m");
    $app->layout($layout);
    $logger->debug("That's the message");
}

mysubroutine();
ok($app->buffer(), 'main::mysubroutine: That\'s the message'); 

############################################################
# Check depth level of %M - with debug(...)
############################################################

$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%M: %m");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), 'main::: That\'s the message'); 

############################################################
# Check Filename and Line #
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%F-%L %m");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), 't/003Layout.t-108 That\'s the message'); 
