###########################################
# Test Suite for Log::Log4perl
# Test two appenders in one category
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 5 };

use Log::Log4perl;
use Data::Dumper;
use Log::Dispatch::Buffer;

my $EG_DIR = "eg";
$EG_DIR = "../eg" unless -d $EG_DIR;

ok(1); # If we made it this far, we're ok.

######################################################################
# Test the root logger on a configuration file defining a file appender
######################################################################
Log::Log4perl->init("$EG_DIR/log4j-manual-3.conf");

my $logger = Log::Log4perl->get_logger("");
$logger->debug("Gurgel");

ok($Log::Dispatch::Buffer::POPULATION[0]->buffer(), 
   'm#^\S+\s+\[N/A\] \(\S+?:\d+\) - Gurgel$#'); 
ok($Log::Dispatch::Buffer::POPULATION[1]->buffer(), 
   'm#^\S+\s+N/A\s+\'\' - Gurgel$#'); 

######################################################################
# Test the root logger via inheritance (discovered by Kevin Goess)
######################################################################
Log::Log4perl->reset();

Log::Log4perl->init("$EG_DIR/log4j-manual-3.conf");

$logger = Log::Log4perl->get_logger("foo");
$logger->debug("Gurgel");

   # POPULATION[1] because it created another buffer behind our back
ok($Log::Dispatch::Buffer::POPULATION[1]->buffer(),
    'm#^\S+\s+N/A \'\' - Gurgel$#'); 
ok($Log::Dispatch::Buffer::POPULATION[1]->buffer(),
    'm#^\S+\s+N/A \'\' - Gurgel$#'); 
#print "BUFFER= '", $Log::Dispatch::Buffer::POPULATION[1]->buffer(), "'\n";
