#Testing if the file-appender appends in default mode

use Test;

use warnings;
use strict;

use Log::Log4perl;

my $testfile = 't/tmp/test26.log';

BEGIN {plan tests => 3}

END { unlink $testfile;
    }

####################################################
#  First, preset the log file with some content
####################################################
open FILE, ">$testfile" or die "Cannot create $testfile";
print FILE "previous content\n";
close FILE;

####################################################
# Append to a log file without specifying append mode
# explicitely
####################################################
my $data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Dispatch::File
log4j.appender.FileAppndr.filename = $testfile
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
my $log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

open FILE, "<$testfile" or die "Cannot create $testfile";
my $content = join '', <FILE>;
close FILE;

ok($content, "previous content\nINFO - Shu-wa-chi!\n");

####################################################
# Clobber the log file if overwriting is required
####################################################
$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Dispatch::File
log4j.appender.FileAppndr.filename = $testfile
log4j.appender.FileAppndr.mode     = write
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

open FILE, "<$testfile" or die "Cannot create $testfile";
$content = join '', <FILE>;
close FILE;

ok($content, "INFO - Shu-wa-chi!\n");

####################################################
# Explicetly say "append"
####################################################
$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Dispatch::File
log4j.appender.FileAppndr.filename = $testfile
log4j.appender.FileAppndr.mode     = append
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

open FILE, "<$testfile" or die "Cannot create $testfile";
$content = join '', <FILE>;
close FILE;

ok($content, "INFO - Shu-wa-chi!\nINFO - Shu-wa-chi!\n");
