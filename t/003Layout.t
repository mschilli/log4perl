###########################################
# Test Suite for Log::Log4perl::Logger
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 4 };

use Log::Log4perl::Layout;
use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Dispatch::Buffer;

my $disp = Log::Dispatch::Buffer->new(
    min_level => "debug",
    name      => "buf",
);

ok(1); # If we made it this far, we're ok.

my $logger = Log::Log4perl::Logger->get_logger("abc.def.ghi");
$logger->add_appender($disp);
$logger->layout("bugo %% %c{2} %-17F{ba} %L hugo");
$logger->debug("That's the message");

ok($disp->buffer(), "bugo  percent def.ghi t/003Layout.t     28 hugo"); 

############################################################
# Log the message
############################################################
$disp->buffer("");
$logger->layout("The message is here: %m");
$logger->debug("That's the message");

ok($disp->buffer(), "The message is here: That's the message"); 

############################################################
# Log the time
############################################################
$disp->buffer("");
$logger->layout("[%r] %m");
$logger->debug("That's the message");

ok($disp->buffer() =~ /^\[\d+\] That's the message$/); 
