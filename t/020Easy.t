# Tests for the lazy man's logger with easy_init()

use warnings;
use strict;

use Test;
use Log::Log4perl qw(:easy);

my $TMP_FILE = "t/tmp/easy";
$TMP_FILE = "tmp/easy" if ! -d "t";

BEGIN { plan tests => 4 }
END   { unlink $TMP_FILE;
        close IN;
      }

ok(1); # Initialized ok
unlink $TMP_FILE;

# Capture STDOUT to a temporary file and a filehandle to read from it
open STDERR, ">$TMP_FILE";
open IN, "<$TMP_FILE" or die "Cannot open $TMP_FILE";
sub readstderr { return join("", <IN>); }

############################################################
# Typical easy setup
############################################################
Log::Log4perl->easy_init($INFO);
my $log = get_logger();
$log->debug("We don't want to see this");
$log->info("But this we want to see");
$log->error("And this also");
my $stderr = readstderr();
#print "STDERR='$stderr'\n";

ok($stderr !~ /don't/);
ok($stderr, 'm#this we want#');
ok($stderr, 'm#this also#');
