###########################################
# Test Suite for Composite Appenders
# Mike Schilli, 2004 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test::More qw(no_plan);

use Log::Log4perl qw(get_logger);
use Log::Log4perl::Level;
use Log::Log4perl::Appender::TestBuffer;

ok(1); # If we made it this far, we/re ok.

##################################################
# Limit Appender
##################################################
# Reset appender population
Log::Log4perl::Appender::TestBuffer->reset();

my $conf = qq(
  log4perl.category = WARN, Limiter

    # Email appender
  log4perl.appender.Buffer          = Log::Log4perl::Appender::TestBuffer
  log4perl.appender.Buffer.layout   = PatternLayout
  log4perl.appender.Buffer.layout.ConversionPattern=%d %m %n

    # Limiting appender, using the email appender above
  log4perl.appender.Limiter         = Log::Log4perl::Appender::Limit
  log4perl.appender.Limiter.appender     = Buffer
  log4perl.appender.Limiter.block_period = 3600
);

Log::Log4perl->init(\$conf);

my $logger = get_logger("");
$logger->warn("This message will be sent immediately");
$logger->warn("This message will be delayed by one hour.");

my $buffer = Log::Log4perl::Appender::TestBuffer->by_name("Buffer");
like($buffer->buffer(), qr/immediately/);
unlike($buffer->buffer(), qr/delayed/);

    # Now flush the limiter and check again. The delayed message should now
    # be there.
my $limit = Log::Log4perl->appenders()->{Limiter};
$limit->flush();

like($buffer->buffer(), qr/immediately/);
like($buffer->buffer(), qr/delayed/);

$buffer->reset();
    # Nothing to flush
$limit->flush();
is($buffer->buffer(), "");

##################################################
# Limit Appender with max_until_discard
##################################################
# Reset appender population
Log::Log4perl::Appender::TestBuffer->reset();

$conf = qq(
  log4perl.category = WARN, Limiter

    # Email appender
  log4perl.appender.Buffer          = Log::Log4perl::Appender::TestBuffer
  log4perl.appender.Buffer.layout   = PatternLayout
  log4perl.appender.Buffer.layout.ConversionPattern=%d %m %n

    # Limiting appender, using the email appender above
  log4perl.appender.Limiter         = Log::Log4perl::Appender::Limit
  log4perl.appender.Limiter.appender     = Buffer
  log4perl.appender.Limiter.block_period = 3600
  log4perl.appender.Limiter.max_until_discarded = 1
);

Log::Log4perl->init(\$conf);

$logger = get_logger("");
$logger->warn("This message will be sent immediately");
for(1..10) {
    $logger->warn("This message will be discarded");
}

    # Artificially flush the limit appender
$limit = Log::Log4perl->appenders()->{Limiter};
$limit->flush();

$buffer = Log::Log4perl::Appender::TestBuffer->by_name("Buffer");
like($buffer->buffer(), qr/immediately/);
unlike($buffer->buffer(), qr/discarded/);

##################################################
# Limit Appender with max_until_discard
##################################################
# Reset appender population
Log::Log4perl::Appender::TestBuffer->reset();

$conf = qq(
  log4perl.category = WARN, Limiter

    # Email appender
  log4perl.appender.Buffer          = Log::Log4perl::Appender::TestBuffer
  log4perl.appender.Buffer.layout   = PatternLayout
  log4perl.appender.Buffer.layout.ConversionPattern=%d %m %n

    # Limiting appender, using the email appender above
  log4perl.appender.Limiter         = Log::Log4perl::Appender::Limit
  log4perl.appender.Limiter.appender     = Buffer
  log4perl.appender.Limiter.block_period = 3600
  log4perl.appender.Limiter.max_until_discarded = 1
);

Log::Log4perl->init(\$conf);

$logger = get_logger("");
$logger->warn("This message will be sent immediately");
for(1..10) {
    $logger->warn("This message will be discarded");
}

    # Artificially flush the limit appender
$limit = Log::Log4perl->appenders()->{Limiter};
$limit->flush();

$buffer = Log::Log4perl::Appender::TestBuffer->by_name("Buffer");
like($buffer->buffer(), qr/immediately/);
unlike($buffer->buffer(), qr/discarded/);

##################################################
# Limit Appender with max_until_flushed
##################################################
# Reset appender population
Log::Log4perl::Appender::TestBuffer->reset();

$conf = qq(
  log4perl.category = WARN, Limiter

    # Email appender
  log4perl.appender.Buffer          = Log::Log4perl::Appender::TestBuffer
  log4perl.appender.Buffer.layout   = PatternLayout
  log4perl.appender.Buffer.layout.ConversionPattern=%d %m %n

    # Limiting appender, using the email appender above
  log4perl.appender.Limiter         = Log::Log4perl::Appender::Limit
  log4perl.appender.Limiter.appender     = Buffer
  log4perl.appender.Limiter.block_period = 3600
  log4perl.appender.Limiter.max_until_flushed = 2
);

Log::Log4perl->init(\$conf);

$logger = get_logger("");
$logger->warn("This message will be sent immediately");
$logger->warn("This message won't show right away");

$buffer = Log::Log4perl::Appender::TestBuffer->by_name("Buffer");
like($buffer->buffer(), qr/immediately/);
unlike($buffer->buffer(), qr/right away/);

$logger->warn("This message will show right away");
like($buffer->buffer(), qr/right away/);
