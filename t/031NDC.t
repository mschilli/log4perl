###########################################
# Test Suite Log::Log4perl::NDC
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test;

use Log::Log4perl qw(get_logger);
use Log::Log4perl::Level;
use Log::Log4perl::TestBuffer;

BEGIN { plan tests => 1 }

# Have TestBuffer log the Log::Dispatch priority
Log::Log4perl::TestBuffer->reset();

my $conf = <<EOT;
log4perl.logger   = ALL, BUF0
log4perl.appender.BUF0           = Log::Log4perl::TestBuffer
log4perl.appender.BUF0.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.BUF0.layout.ConversionPattern = %m <%x>
EOT

Log::Log4perl::init(\$conf);

my $app0 = Log::Log4perl::TestBuffer->by_name("BUF0");

my $loga = get_logger("a");


Log::Log4perl::NDC->push("first");
$loga->debug("debug");

    # Push more than MAX
Log::Log4perl::NDC->push("second");
Log::Log4perl::NDC->push("third");
Log::Log4perl::NDC->push("fourth");
Log::Log4perl::NDC->push("fifth");
Log::Log4perl::NDC->push("sixth");
$loga->info("info");

    # Delete NDC stack
Log::Log4perl::NDC->remove();
$loga->warn("warn");

Log::Log4perl::NDC->push("seventh");
$loga->error("error");

ok($app0->buffer(), 
   "debug <first>info <sixth>warn <[undef]>error <seventh>");
