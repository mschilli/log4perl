#Testing double-init

BEGIN {
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Test;

use warnings;
use strict;

use Log::Log4perl;
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir);

my $WORK_DIR = tmpdir();
my $testfilea = File::Spec->catfile($WORK_DIR, qw(test18a.log));
my $testfileb = File::Spec->catfile($WORK_DIR, qw(test18b.log));

BEGIN {plan tests => 2}

####################################################
# Double-Init, 2nd time with different log file name
####################################################
my $data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
log4j.appender.FileAppndr.filename = $testfilea
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
my $log = Log::Log4perl::get_logger("");

$log->info("Shu-wa-chi!");

$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
log4j.appender.FileAppndr.filename = $testfileb
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger();

$log->info("Shu-wa-chi!");

# Check if both files contain one message each
for my $file ($testfilea, $testfileb) {
    open FILE, "<$file" or die "Cannot open $file";
    my $content = join '', <FILE>;
    close FILE;
    ok($content, "INFO - Shu-wa-chi!\n");
}

reset_logger();

sub reset_logger {
  local $Log::Log4perl::Config::CONFIG_INTEGRITY_CHECK = 0; # to close handles and allow temp files to go
  Log::Log4perl::init(\'');
}
