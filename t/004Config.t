###########################################
# Test Suite for Log::Log4perl
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 3 };

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


ok($Log::Log4perl::TestBuffer::POPULATION[0]->buffer(), 
   'm#^\d+\s+\[N/A\] DEBUG  N/A - Gurgel$#'); 
#print "BUFFER= '", $Log::Log4perl::TestBuffer::POPULATION[0]->buffer(), "'\n";

######################################################################
# Test the root logger via inheritance (discovered by Kevin Goess)
######################################################################
Log::Log4perl->reset();

$Log::Log4perl::TestBuffer::POPULATION[0]->buffer('');

Log::Log4perl->init("$EG_DIR/log4j-manual-1.conf");

$logger = Log::Log4perl->get_logger("foo");
$logger->debug("Gurgel");

ok($Log::Log4perl::TestBuffer::POPULATION[0]->buffer(),
    'm#^\d+\s+\[N/A\] DEBUG foo N/A - Gurgel$#'); 
#print "BUFFER= '", $Log::Log4perl::TestBuffer::POPULATION[1]->buffer(), "'\n";
