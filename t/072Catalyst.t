###########################################
# Test Suite for Log::Log4perl::Catalyst
###########################################

BEGIN {
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use strict;
use warnings;
use Test::More;

use Log::Log4perl;
use Log::Log4perl::Catalyst;
use Log::Log4perl::Appender::TestBuffer;

my $conf = qq(
log4perl.category            = DEBUG, Root
log4perl.appender.Root        = Log::Log4perl::Appender::TestBuffer
log4perl.appender.Root.layout = SimpleLayout

log4perl.logger.api          = INFO, Api
log4perl.additivity.api      = 0
log4perl.appender.Api        = Log::Log4perl::Appender::TestBuffer
log4perl.appender.Api.layout = SimpleLayout
);

# Mount two Catalyst apps in the one process, which is ordinary enough under
# Plack::Builder, and they'll each build a logger from the same config. That's
# all this is doing.
#
# With autoflush off, the constructor sticks a buffer in front of every
# appender and tells the loggers to write to the buffer instead. Do that twice
# and the second time round builds a fresh set of buffers, drops them into the
# registry on top of the old ones, and then only fixes up the loggers that are
# still writing to the raw appender. Any logger the first pass already moved is
# left behind, still writing to a buffer that nothing can get at any more.
# _flush() goes through the registry, so it empties the new buffers while the
# message is sat in the old one, and the line just quietly vanishes.
my $app1_log = Log::Log4perl::Catalyst->new(\$conf);
my $app2_log = Log::Log4perl::Catalyst->new(\$conf);

Log::Log4perl->get_logger("api")->info("a logged message");

# What Catalyst::handle_request() does after finalize on every request.
$app2_log->_flush();

like(Log::Log4perl::Appender::TestBuffer->by_name("Api")->buffer(),
     qr/a logged message/,
     "message survives a second Log::Log4perl::Catalyst construction");

done_testing();
