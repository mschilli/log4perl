###########################################
# Test Suite for Log::Log4perl
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 6 };

use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Dispatch::Buffer;

my $disp = Log::Dispatch::Buffer->new(
    min_level => "debug",
    name      => "buf",
);

ok(1); # If we made it this far, we're ok.

my $logger = Log::Log4perl->get_logger("abc.def.ghi");
$logger->add_appender('buf',$disp);
$logger->layout(new Log::Log4perl::Layout::PatternLayout('buf',"bugo %% %c{2} %-17F{ba} %L hugo",));
$logger->debug("That's the message");

ok($disp->buffer(), "bugo  percent def.ghi t/003Layout.t     28 hugo"); 

############################################################
# Log the message
############################################################
$disp->buffer("");
$logger->layout(new Log::Log4perl::Layout::PatternLayout('buf',"The message is here: %m"));
$logger->debug("That's the message");

ok($disp->buffer(), "The message is here: That's the message"); 

############################################################
# Log the time
############################################################
$disp->buffer("");
$logger->layout(new Log::Log4perl::Layout::PatternLayout('buf',"[%r] %m"));
$logger->debug("That's the message");

ok($disp->buffer() =~ /^\[\d+\] That's the message$/); 

############################################################
# Log the date/time
############################################################
$disp->buffer("");
$logger->layout(new Log::Log4perl::Layout::PatternLayout('buf',"%d> %m"));
$logger->debug("That's the message");

ok($disp->buffer(), 
   'm#^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d> That\'s the message$#'); 

############################################################
# Check SimpleLayout
############################################################
$disp->buffer("");
$logger->layout(new Log::Log4perl::Layout::SimpleLayout('buf',"%d> %m"));
$logger->debug("That's the message");

ok($disp->buffer(), 
   'DEBUG - That\'s the message'); 


