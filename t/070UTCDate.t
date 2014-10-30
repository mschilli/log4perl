###########################################
# Tests for Log4perl::DateFormat with gmtime
###########################################

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use warnings;
use strict;

use Test::More;

BEGIN { plan tests => 2 }

use Log::Log4perl qw(get_logger);
use Log::Log4perl::Appender::TestBuffer;

sub init_with_utc {
    my ($utc) = @_;
    my $conf = <<'CONF';
log4perl.category.Bar.Twix      = WARN, Buffer
log4perl.appender.Buffer        = Log::Log4perl::Appender::TestBuffer
log4perl.appender.Buffer.layout = \
    Log::Log4perl::Layout::PatternLayout
log4perl.appender.Buffer.layout.ConversionPattern = %d{HH:mm:ss}%n
CONF
    if (defined $utc) {
        $conf .= "log4perl.utcDateTimes = $utc\n";
    }

    Log::Log4perl::init(\$conf);
}

init_with_utc(1);
ok $Log::Log4perl::DateFormat::GMTIME, "init_with_utc";

init_with_utc(0);
ok ! $Log::Log4perl::DateFormat::GMTIME, "init_with_utc";
