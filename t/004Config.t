###########################################
# Test Suite for Log::Log4perl
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 5 };

use Log::Log4perl;
use Log::Log4perl::TestBuffer;

my $EG_DIR = "eg";
$EG_DIR = "../eg" unless -d $EG_DIR;

ok(1); # If we made it this far, we're ok.

######################################################################
# Test the root logger on a configuration file defining a file appender
######################################################################
Log::Log4perl->init("$EG_DIR/log4j-manual-1.conf");

my $logger = Log::Log4perl->get_logger("");
$logger->debug("Gurgel");


ok(Log::Log4perl::TestBuffer->by_name("A1")->buffer(), 
   'm#^\d+\s+\[N/A\] DEBUG  N/A - Gurgel$#'); 

######################################################################
# Test the root logger via inheritance (discovered by Kevin Goess)
######################################################################
Log::Log4perl::TestBuffer->reset();

Log::Log4perl->init("$EG_DIR/log4j-manual-1.conf");

$logger = Log::Log4perl->get_logger("foo");
$logger->debug("Gurgel");

ok(Log::Log4perl::TestBuffer->by_name("A1")->buffer(),
    'm#^\d+\s+\[N/A\] DEBUG foo N/A - Gurgel$#'); 

######################################################################
# Test init with a string
######################################################################
Log::Log4perl::TestBuffer->reset();

Log::Log4perl->init(\ <<EOT);
log4j.rootLogger=DEBUG, A1
log4j.appender.A1=Log::Log4perl::TestBuffer
log4j.appender.A1.layout=org.apache.log4j.PatternLayout
log4j.appender.A1.layout.ConversionPattern=%-4r [%t] %-5p %c %x - %m%n
EOT

$logger = Log::Log4perl->get_logger("foo");
$logger->debug("Gurgel");

ok(Log::Log4perl::TestBuffer->by_name("A1")->buffer(),
    'm#^\d+\s+\[N/A\] DEBUG foo N/A - Gurgel$#'); 

######################################################################
# Test init with a hashref
######################################################################
Log::Log4perl::TestBuffer->reset();

my %hash = (
    "log4j.rootLogger"         => "DEBUG, A1",
    "log4j.appender.A1"        => "Log::Log4perl::TestBuffer",
    "log4j.appender.A1.layout" => "org.apache.log4j.PatternLayout",
    "log4j.appender.A1.layout.ConversionPattern" => 
                                  "%-4r [%t] %-5p %c %x - %m%n"
    );

Log::Log4perl->init(\%hash);

$logger = Log::Log4perl->get_logger("foo");
$logger->debug("Gurgel");

ok(Log::Log4perl::TestBuffer->by_name("A1")->buffer(),
    'm#^\d+\s+\[N/A\] DEBUG foo N/A - Gurgel$#'); 
