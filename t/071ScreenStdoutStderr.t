BEGIN {
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use warnings;
use strict;

use Log::Log4perl qw(:easy :no_extra_logdie_message);
use Test::More;
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir);

BEGIN {
    if ($] < 5.008) {
        plan skip_all => "Only with perl >= 5.008";
    } else {
        plan tests => 30;
    }
}

#########################################################################
# Capture STDERR to a temporary file and a filehandle to read from it

++$|;
my $WORK_DIR        = tmpdir();
my $TMP_FILE_STDOUT = File::Spec->catfile($WORK_DIR, qw(stdout));
my $TMP_FILE_STDERR = File::Spec->catfile($WORK_DIR, qw(stderr));

open STDOUT, '>', $TMP_FILE_STDOUT;
open STDERR, '>', $TMP_FILE_STDERR;
open IN_STDOUT, '<', $TMP_FILE_STDOUT or die "Cannot open $TMP_FILE_STDOUT"; binmode IN_STDOUT, ":utf8";
open IN_STDERR, '<', $TMP_FILE_STDERR or die "Cannot open $TMP_FILE_STDERR"; binmode IN_STDERR, ":utf8";
sub readstdout { return join("", <IN_STDOUT>); }
sub readstderr { return join("", <IN_STDERR>); }

END   { unlink $TMP_FILE_STDOUT;
        unlink $TMP_FILE_STDERR;
        close IN_STDOUT;
        close IN_STDERR;
}
#########################################################################

# Tests for all stdout
my %tests = (
    debug   => { stderr => 0, code => \&DEBUG   },
    info    => { stderr => 0, code => \&INFO    },
    warn    => { stderr => 0, code => \&WARN    },
    error   => { stderr => 0, code => \&ERROR   },
    fatal   => { stderr => 0, code => \&FATAL   },
);

my $conf = qq(
log4perl.category               = DEBUG, Screen

# Regular Screen Appender
log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
log4perl.appender.Screen.stderr = 0
);

do_tests( $conf, \%tests );

# Test for all stderr - reset our captures and set stderr to 1
truncate STDOUT, 0;
truncate STDERR, 0;
++$tests{ $_ }{stderr} for (keys %tests);

$conf = qq(
log4perl.category               = DEBUG, Screen

# Regular Screen Appender
log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
log4perl.appender.Screen.stderr = 1
);

do_tests( $conf, \%tests );

# Tests for mixed stdout and stderr - reset our captures and set some to stdout
truncate STDOUT, 0;
truncate STDERR, 0;
--$tests{debug}{stderr};
--$tests{info}{stderr};
--$tests{warn}{stderr};

$conf = qq(
log4perl.category                       = DEBUG, Screen

# Regular Screen Appender
log4perl.appender.Screen                = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.layout         = Log::Log4perl::Layout::SimpleLayout
log4perl.appender.Screen.stderr.ERROR   = 1
# Lower case test
log4perl.appender.Screen.stderr.fatal   = 1
);

do_tests( $conf, \%tests );

sub do_tests {
    my ($conf, $tests) = @_;

    Log::Log4perl->init(\$conf);

    for my $level (sort keys %{ $tests }) {
        # e.g. "DEBUG('debug')"
        $tests->{ $level }{code}->( $level );
        is( readstdout() =~ /$level/ ? 0 : 1, $tests->{ $level }{stderr}, $level . ' to stdout');
        is( readstderr() =~ /$level/ ? 1 : 0, $tests->{ $level }{stderr}, $level . ' to stderr');
    }
}
