###########################################
# Test Suite for Log::Log4perl::Config
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;

#create a custom level "LITEWARN"
BEGIN {
package Log::Log4perl::Level;
our %PRIORITY = (
    "FATAL" => 0,
    "ERROR" => 3,
    "WARN"  => 4,
    "LITEWARN"  => 5,
    "INFO"  => 6,
    "DEBUG" => 7,
);
}


use Log::Log4perl;
use Log::Log4perl::Level;
use Log::Log4perl::TestBuffer;


ok(1); # If we made it this far, we're ok.

my $LOGFILE = "example.log";
unlink $LOGFILE;

my $config = <<EOT;
log4j.category = LITEWARN, FileAppndr
log4j.appender.FileAppndr          = Log::Dispatch::File
log4j.appender.FileAppndr.filename = $LOGFILE
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT



Log::Log4perl::init(\$config);


# *********************
# check a category logger

my $logger = Log::Log4perl->get_logger("groceries.beer");
$logger->warn("this is a warning message");
$logger->litewarn("this is a LITE warning message (2/3 the calories)");
$logger->info("this info message should not log");


open FILE, "<$LOGFILE" or die "Cannot open $LOGFILE";
$/ = undef;
my $data = <FILE>;
close FILE;
my $result1 = "WARN - this is a warning message\nLITEWARN - this is a LITE warning message (2/3 the calories)\n";
ok($data, $result1);

# *********************
# check the root logger
my $rootlogger = Log::Log4perl->get_logger("");
$logger->warn("this is a rootlevel warning message");
$logger->litewarn("this is a rootlevel  LITE warning message (2/3 the calories)");
$logger->info("this rootlevel  info message should not log");

open FILE, "<$LOGFILE" or die "Cannot open $LOGFILE";
$/ = undef;
$data = <FILE>;
close FILE;
my $result2 = "WARN - this is a rootlevel warning message\nLITEWARN - this is a rootlevel  LITE warning message (2/3 the calories)\n";
ok($data, "$result1$result2");

$logger->log($WARN, "a warning message");
$logger->log($LITEWARN, "a LITE warning message");
$logger->log($DEBUG, "an info message, should not log");

open FILE, "<$LOGFILE" or die "Cannot open $LOGFILE";
$/ = undef;
$data = <FILE>;
close FILE;
my $result3 = "WARN - a warning message\nLITEWARN - a LITE warning message\n";
ok($data, "$result1$result2$result3");

#*********************
#check the is_* methods
ok($logger->is_warn);
ok($logger->is_litewarn);
ok(! $logger->is_info);


#***************************
#increase/decrease leves
$logger->inc_level();  #bump up from litewarn to warn
ok($logger->is_warn);
ok(!$logger->is_litewarn);
ok(!$logger->is_info);
$logger->warn("after bumping, warning message");
$logger->litewarn("after bumping, lite warning message, should not log");
open FILE, "<$LOGFILE" or die "Cannot open $LOGFILE";
$/ = undef;
$data = <FILE>;
close FILE;
my $result4 = "WARN - after bumping, warning message\n";
ok($data, "$result1$result2$result3$result4");


$logger->dec_level(2); #bump down from warn to litewarn to info
ok($logger->is_warn);
ok($logger->is_litewarn);
ok($logger->is_info);
ok(! $logger->is_debug) ;


BEGIN { plan tests => 15 };

unlink $LOGFILE;
