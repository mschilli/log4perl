###########################################
# Test Suite for :no_extra_logdie_message
# Mike Schilli, 2005 (m@perlmeister.com)
###########################################

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use strict;
use warnings;
use Log::Log4perl qw(:easy :no_extra_logdie_message);
use Test::More;
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir);

BEGIN {
    if ($] < 5.008) {
        plan skip_all => "Only with perl >= 5.008";
    }
}

use Log::Log4perl::Appender::TestBuffer;

is($Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR, 0, "internal variable set");

my $conf = qq(
log4perl.category                  = DEBUG, Screen

    # Regular Screen Appender
log4perl.appender.Screen           = Log::Log4perl::Appender::TestBuffer
log4perl.appender.Screen.layout    = PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %p %c %m %n
);

Log::Log4perl->init(\$conf);

#########################################################################
# Capture STDERR to a temporary file and a filehandle to read from it

my $WORK_DIR = tmpdir();
my $TMP_FILE = File::Spec->catfile($WORK_DIR, qw(easy));

open STDERR, ">$TMP_FILE";
select STDERR; $| = 1; #needed on win32
open IN, "<$TMP_FILE" or die "Cannot open $TMP_FILE"; binmode IN, ":utf8";
sub readstderr { return join("", <IN>); }

END   { unlink $TMP_FILE;
        close IN;
      }
#########################################################################

my $buf = Log::Log4perl::Appender::TestBuffer->by_name("Screen");

$buf->buffer("");
my $line_ref = __LINE__ + 1;
LOGCARP("logcarp");

like(readstderr(), qr/logcarp at /, "Output to stderr");
SKIP: { use Carp;
    skip "Detected buggy Carp.pm (upgrade to perl-5.8.*)", 3 unless 
        defined $Carp::VERSION;
    like($buf->buffer(), qr/logcarp.*$line_ref/, "Appender output intact");
    $buf->buffer("");
    $line_ref = __LINE__ + 1;
    LOGCARP("logcarp");
    like(readstderr(), qr/logcarp at /, "Output to stderr");
    like($buf->buffer(), qr/logcarp.*$line_ref/, "Appender output intact");
}

$line_ref += 6;
$buf->clear;
LOGWARN("Doesn't call 'exit'");
is(readstderr(), "", "No output to stderr");
like($buf->buffer(), qr/Doesn't call 'exit'/, "Appender output intact");
#########################################################################
# Turn default behaviour back on
#########################################################################
$Log::Log4perl::LOGDIE_MESSAGE_ON_STDERR ^= 1;
$buf->buffer("");

package Foo;
use Log::Log4perl qw(:easy);
sub foo {
    LOGCARP("logcarp");
}
package main;

Foo::foo();

$line_ref += 17;
like(readstderr(), qr/logcarp.*$line_ref/, "Output to stderr");
like($buf->buffer(), qr/logcarp.*$line_ref/, "Appender output intact");

$buf->buffer("");
eval {
    LOGDIE("logdie");
};
$line_ref += 8;
like($@, qr/logdie.*$line_ref/, "Output to stderr");
like($buf->buffer(), qr/logdie/, "Appender output intact");

done_testing;
