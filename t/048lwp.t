###########################################
# Test Suite for LWP debugging with Log4perl
# Mike Schilli, 2004 (m@perlmeister.com)
###########################################

use warnings;
use strict;

use Test::More;

BEGIN {
    eval {
        require LWP::UserAgent;

        if($@) {
            plan skip_all => "Only with LWP::UserAgent";
        } else {
            plan tests => 3;
        }
    }
}

use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init(
    { level    => $DEBUG,
      category => "LWP::UserAgent",
      file     => 'lwpout.txt'
    });

Log::Log4perl->infiltrate_lwp();

my $ua = LWP::UserAgent->new();
$ua->get("file:/tmp/foobar");

open LOG, "<lwpout.txt" or die "Cannot open lwpout.txt";
my $data = join('', <LOG>);
close LOG;

like($data, qr#GET file:/tmp/foobar#);

END { unlink "lwpout.txt" }

####################################
# Check different category
####################################
Log::Log4perl->reset();
Log::Log4perl->easy_init(
    { level    => $DEBUG,
      category => "LWP::SchmoozeAgent",
      file     => '>lwpout.txt'
    });

Log::Log4perl->infiltrate_lwp();

$ua = LWP::UserAgent->new();
$ua->get("file:/tmp/foobar");

open LOG, "<lwpout.txt" or die "Cannot open lwpout.txt";
$data = join('', <LOG>);
close LOG;

is($data, '');

####################################
# Check layout
####################################
Log::Log4perl->reset();
Log::Log4perl->easy_init(
    { level    => $DEBUG,
      category => "LWP::UserAgent",
      file     => '>lwpout.txt',
      layout   => '%F-%L: %m%n',
    });

Log::Log4perl->infiltrate_lwp();

$ua = LWP::UserAgent->new();
$ua->get("file:/tmp/foobar");

open LOG, "<lwpout.txt" or die "Cannot open lwpout.txt";
$data = join('', <LOG>);
close LOG;

like($data, qr#LWP/UserAgent.pm-\d+#);
