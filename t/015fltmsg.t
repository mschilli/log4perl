###########################################
# Test Suite for Log::Log4perl
# filter_message cases
# Mike Schilli, 2003 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test::More tests => 4;

use Log::Log4perl;
use Log::Log4perl::Appender::TestBuffer;

my $EG_DIR = "eg";
$EG_DIR = "../eg" unless -d $EG_DIR;

######################################################################
# filter_message undef: Concatenation
######################################################################
Log::Log4perl->init( \ <<EOT );
    log4perl.rootLogger=DEBUG, A1
    log4perl.appender.A1=Log::Log4perl::Appender::TestBuffer
    log4perl.appender.A1.layout=PatternLayout
    log4perl.appender.A1.layout.ConversionPattern=%m%n
EOT

my $app = Log::Log4perl::Appender::TestBuffer->by_name("A1");
my $logger = Log::Log4perl->get_logger("");
$logger->debug("Chunk1", "Chunk2", "Chunk3");

is($app->buffer(), "Chunk1Chunk2Chunk3\n", "filter_message undef"); 

######################################################################
# filter_message undef: Concatenation plus JOIN_MSG_ARRAY_CHAR
######################################################################
Log::Log4perl->init( \ <<EOT );
    log4perl.rootLogger=DEBUG, A1
    log4perl.appender.A1=Log::Log4perl::Appender::TestBuffer
    log4perl.appender.A1.layout=PatternLayout
    log4perl.appender.A1.layout.ConversionPattern=%m%n
EOT

$Log::Log4perl::JOIN_MSG_ARRAY_CHAR = "bang!";

my $app = Log::Log4perl::Appender::TestBuffer->by_name("A1");
$logger = Log::Log4perl->get_logger("");
$logger->debug("Chunk1", "Chunk2", "Chunk3");

is($app->buffer(), "Chunk1bang!Chunk2bang!Chunk3\n", 
   "filter_message undef (JOIN_MSG_ARRAY_CHAR)"); 

$Log::Log4perl::JOIN_MSG_ARRAY_CHAR = ""; # back to default

######################################################################
# filter_message 0
######################################################################
Log::Log4perl->init( \ <<EOT );
    log4perl.rootLogger=DEBUG, A1
    log4perl.appender.A1=Log::Log4perl::Appender::TestArrayBuffer
    log4perl.appender.A1.layout=NoopLayout
    log4perl.appender.A1.filter_message=0
EOT

my $app = Log::Log4perl::Appender::TestArrayBuffer->by_name("A1");
$logger = Log::Log4perl->get_logger("");
$logger->debug("Chunk1", "Chunk2", "Chunk3");

is($app->buffer(), "[Chunk1,Chunk2,Chunk3]", 
   "filter_message 0 (NoopLayout)"); 

######################################################################
# filter_message = function
######################################################################
my $COUNTER = 0;
sub filter_my_message {
    my @chunks = @{$_[0]};
    unshift @chunks, ++$COUNTER;
    return \@chunks;
}

Log::Log4perl->init( \ <<'EOT' );
    log4perl.rootLogger=DEBUG, A1
    log4perl.appender.A1=Log::Log4perl::Appender::TestArrayBuffer
    log4perl.appender.A1.layout=NoopLayout
    log4perl.appender.A1.filter_message = main::filter_my_message
EOT

my $app = Log::Log4perl::Appender::TestArrayBuffer->by_name("A1");
$logger = Log::Log4perl->get_logger("");
$logger->debug("Chunk1", "Chunk2", "Chunk3");

is($app->buffer(), "[1,Chunk1,Chunk2,Chunk3]", 
   "filter_message = function");
