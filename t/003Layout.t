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
BEGIN { plan tests => 16 };

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Log4perl::Appender::TestBuffer;
use File::Spec;

my $app = Log::Log4perl::Appender->new(
    "Log::Log4perl::Appender::TestBuffer");

ok(1); # If we made it this far, we're ok.

my $logger = Log::Log4perl->get_logger("abc.def.ghi");
$logger->add_appender($app);
my $layout = Log::Log4perl::Layout::PatternLayout->new(
    "bugo %% %c{2} %-17F{2} %L hugo");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), "bugo % def.ghi " . 
                   File::Spec->catfile(qw(t 003Layout.t)) .
                   "     32 hugo"); 

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

ok($app->buffer(), File::Spec->catfile(qw(t 003Layout.t)) .
                   "-111 That's the message"); 

############################################################
# Don't append a newline if the message already contains one
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%m%n");
$app->layout($layout);
$logger->debug("That's the message\n");

ok($app->buffer(), "That\'s the message\n");

############################################################
# But don't suppress other %ns
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("a%nb%n%m%n");
$app->layout($layout);
$logger->debug("That's the message\n");

ok($app->buffer(), "a\nb\nThat\'s the message\n");

############################################################
# Test if the process ID works
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%P:%m");
$app->layout($layout);
$logger->debug("That's the message\n");

ok($app->buffer() =~ /^\d+:That's the message$/);

############################################################
# Test if the hostname placeholder %H works
############################################################
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%H:%m");
$app->layout($layout);
$logger->debug("That's the message\n");

ok($app->buffer() =~ /^[^:]+:That's the message$/);

############################################################
# Test max width in the format specifiers
############################################################
#min width
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%5.5m");
$app->layout($layout);
$logger->debug("123");
ok($app->buffer(), '  123');

#max width
$app->buffer("");
$logger->debug("1234567");
ok($app->buffer(), '12345');

#left justify
$app->buffer("");
$layout = Log::Log4perl::Layout::PatternLayout->new("%-5.5m");
$app->layout($layout);
$logger->debug("123");
ok($app->buffer(), '123  ');
