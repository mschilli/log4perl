###########################################
# Test Suite for 'Buffer' appender
# Mike Schilli, 2004 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test::More tests => 3;
use Log::Log4perl::Appender::TestBuffer;

use Log::Log4perl qw(:easy);

my $conf = qq(
log4perl.category                  = DEBUG, Buffer

    # Regular Screen Appender
log4perl.appender.Screen           = Log::Log4perl::Appender::TestBuffer
log4perl.appender.Screen.layout    = PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %p %c %m %n

    # Buffering appender, using the appender above as outlet
log4perl.appender.Buffer               = Log::Log4perl::Appender::Buffer
log4perl.appender.Buffer.appender      = Screen
log4perl.appender.Buffer.trigger_level = ERROR
);

Log::Log4perl->init(\$conf);

my $buf = Log::Log4perl::Appender::TestBuffer->by_name("Screen");

DEBUG("This message gets buffered.");
is($buf->buffer(), "", "Buffering DEBUG");

INFO("This message gets buffered also.");
is($buf->buffer(), "", "Buffering INFO");

ERROR("This message triggers a buffer flush.");
like($buf->buffer(), qr/DEBUG.*?INFO.*?ERROR/s, "Flushing ERROR");
