###########################################
# Tests for Log4perl::DateFormat
# Gianni Ceccarelli, 2014 (dakkar@thenautilus.net)
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

sub zero_offset { return( (join '-',gmtime) eq (join '-',localtime) ) }

BEGIN {
    my $zero_offset = zero_offset;
    if ($zero_offset) {
        $ENV{TZ}='UTC+3';
        $zero_offset = zero_offset;
    }
    if ($zero_offset) {
        plan skip_all => "gmtime and localtime are the same, can't test";
    }
    else {
        plan tests => 2;
    }
}

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

    return get_logger("Bar::Twix");
}

my $logger;
sub log_string_for {
    my $buffer = Log::Log4perl::Appender::TestBuffer->by_name("Buffer");
    $buffer->clear();
    $logger->error(@_);
    return $buffer->buffer();
}

# default
$logger = init_with_utc();
my $default_string = log_string_for('blah');
note "default: $default_string";

$logger = init_with_utc(1);
my $utc_string = log_string_for('blah');
note "UTC: $utc_string";

$logger = init_with_utc(0);
my $local_string = log_string_for('blah');
note "local: $local_string";

is($default_string,$local_string,'use localtime by default');
isnt($utc_string,$local_string,'gmtime != localtime');
