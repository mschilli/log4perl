#!/usr/bin/perl
##########################################################################
# Check basic variable substitution.
# Mike Schilli, 2003 (m@perlmeister.com)
##########################################################################
use warnings;
use strict;

use Test::More qw(no_plan);
use Log::Log4perl qw(get_logger);

########################################################
# Wrong variable name
########################################################
my $conf = q(
screen = Log::Log4perl::Appender::Screen
log4perl.category = WARN, ScreenApp
log4perl.appender.ScreenApp = ${screen1}
log4perl.appender.ScreenApp.layout = \
    Log::Log4perl::Layout::PatternLayout
log4perl.appender.ScreenApp.layout.ConversionPattern = %d %F{1} %L> %m %n
);

eval { Log::Log4perl::init(\$conf) };

like($@, qr/Undefined Variable 'screen1'/);

########################################################
# Replacing appender class name
########################################################
$conf = q(
screen = Log::Log4perl::Appender::TestBuffer
log4perl.category = WARN, BufferApp
log4perl.appender.BufferApp = ${screen}
log4perl.appender.BufferApp.layout = \
    Log::Log4perl::Layout::PatternLayout
log4perl.appender.BufferApp.layout.ConversionPattern = %d %F{1} %L> %m %n
);

Log::Log4perl::init(\$conf);
my $logger = get_logger("");
$logger->error("foobar");
my $buffer = Log::Log4perl::Appender::TestBuffer->by_name("BufferApp");
like($buffer->buffer, qr/foobar/);

