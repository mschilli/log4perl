#Testing if the file-appender appends in default mode

BEGIN {
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use strict;
use warnings;
use Test::More;
use Log::Log4perl;
use File::Spec;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Log4perlInternalTest qw( is_like_windows tmpdir );

our $LOG_DISPATCH_PRESENT;

BEGIN {
    eval { require Log::Dispatch; };
    if(! $@) {
       $LOG_DISPATCH_PRESENT = 1;
    }
};

my $WORK_DIR = tmpdir();
my $testfile = File::Spec->catfile($WORK_DIR, "test26.log");
my $testpath = File::Spec->catdir($WORK_DIR, "test26");

####################################################
#  First, preset the log file with some content
####################################################
open FILE, ">$testfile" or die "Cannot create $testfile";
print FILE "previous content\n";
close FILE;

####################################################
# Append to a log file without specifying append mode
# explicitly
####################################################
my $data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
log4j.appender.FileAppndr.filename = $testfile
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
my $log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

open FILE, "<$testfile" or die "Cannot create $testfile";
my $content = join '', <FILE>;
close FILE;

is($content, "previous content\nINFO - Shu-wa-chi!\n");

####################################################
# Clobber the log file if overwriting is required
####################################################
$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
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

is($content, "INFO - Shu-wa-chi!\n");

####################################################
# Explicetly say "append"
####################################################
$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
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

is($content, "INFO - Shu-wa-chi!\nINFO - Shu-wa-chi!\n");

#########################################################
# Mix Log::Dispatch and Log::Log4perl::Appender appenders
#########################################################
SKIP: {
  skip "Skipping Log::Dispatch tests", 2 unless $LOG_DISPATCH_PRESENT;

$data = <<EOT;
log4perl.category = INFO, FileAppndr1, FileAppndr2
log4perl.appender.FileAppndr1          = Log::Dispatch::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.mode     = append
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout

log4perl.appender.FileAppndr2          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr2.filename = ${testfile}_2
log4perl.appender.FileAppndr2.mode     = append
log4perl.appender.FileAppndr2.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

for(qw(1 2)) {
    open FILE, "<${testfile}_$_" or die "Cannot open ${testfile}_$_";
    $content = join '', <FILE>;
    close FILE;

    is($content, "INFO - Shu-wa-chi!\n");
}
};

#########################################################
# Check if the 0.33 Log::Log4perl::Appender::File bug is
# fixed which caused all messages to end up in the same
# file.
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1, FileAppndr2
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout

log4perl.appender.FileAppndr2          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr2.filename = ${testfile}_2
log4perl.appender.FileAppndr2.mode     = write
log4perl.appender.FileAppndr2.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

for(qw(1 2)) {
    open FILE, "<${testfile}_$_" or die "Cannot open ${testfile}_$_";
    $content = join '', <FILE>;
    close FILE;

    is($content, "INFO - Shu-wa-chi!\n");
}

#########################################################
# Check if switching over to a new file will work
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

my $app = Log::Log4perl->appenders()->{FileAppndr1};
$app->file_switch("${testfile}_2");
$log->info("File2");

for(qw(1 2)) {
    open FILE, "<${testfile}_$_" or die "Cannot open ${testfile}_$_";
    $content = join '', <FILE>;
    close FILE;

    is($content, "INFO - File$_\n");
}

is($app->filename(), "${testfile}_2");

#########################################################
# Testing syswrite
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.syswrite = 1
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

open FILE, "<${testfile}_1" or die "Cannot open ${testfile}_1";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\n");

Log::Log4perl::init(\$data);
$log->info("File1");

open FILE, "<${testfile}_1" or die "Cannot open ${testfile}_1";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\n");

#########################################################
# Testing syswrite with append
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.syswrite = 1
log4perl.appender.FileAppndr1.mode     = append
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

open FILE, "<${testfile}_1" or die "Cannot open ${testfile}_1";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\nINFO - File1\n");

#########################################################
# Testing syswrite and recreate
#########################################################
SKIP: {
  skip "File recreation not supported on Win32", 1 if is_like_windows();
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.syswrite = 1
log4perl.appender.FileAppndr1.recreate = 1
log4perl.appender.FileAppndr1.recreate_check_interval = 0
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

unlink "${testfile}_1";

$log->info("File1-1");

open FILE, "<${testfile}_1" or die "Cannot open ${testfile}_1";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1-1\n");
};

#########################################################
# Testing syswrite and recreate without check_interval
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.syswrite = 1
log4perl.appender.FileAppndr1.recreate = 1
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

unlink "${testfile}_1";

eval { $log->info("File1-1"); };

is($@, "", "no error on moved file/syswrite");

SKIP: {
  skip "Signals not supported on Win32", 2 if is_like_windows();

#########################################################
# Testing syswrite and recreate_check_signal
#########################################################
$data = <<EOT;
log4perl.category = INFO, FileAppndr1
log4perl.appender.FileAppndr1          = Log::Log4perl::Appender::File
log4perl.appender.FileAppndr1.filename = ${testfile}_1
log4perl.appender.FileAppndr1.syswrite = 1
log4perl.appender.FileAppndr1.recreate = 1
log4perl.appender.FileAppndr1.recreate_check_signal = USR1
log4perl.appender.FileAppndr1.mode     = write
log4perl.appender.FileAppndr1.layout   = Log::Log4perl::Layout::SimpleLayout
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("File1");

unlink "${testfile}_1";

is(kill('USR1', $$), 1, "sending signal");
$log->info("File1");

open FILE, "<${testfile}_1" or die "Cannot open ${testfile}_1";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\n");
};

#########################################################
# Testing create_at_logtime
#########################################################
unlink "${testfile}_3"; # delete leftovers from previous tests

$data = qq(
log4perl.category         = DEBUG, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = ${testfile}_3
log4perl.appender.Logfile.create_at_logtime = 1
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::SimpleLayout
);

Log::Log4perl->init(\$data);
ok(! -f "${testfile}_3");

$log = Log::Log4perl::get_logger("");
$log->info("File1");

open FILE, "<${testfile}_3" or die "Cannot open ${testfile}_3";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\n");

unlink "${testfile}_3";

#########################################################
# Testing create_at_logtime with recreate_check_signal
#########################################################
unlink "${testfile}_4"; # delete leftovers from previous tests

$data = qq(
log4perl.category         = DEBUG, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = ${testfile}_4
log4perl.appender.Logfile.create_at_logtime = 1
log4perl.appender.Logfile.recreate = 1;
log4perl.appender.Logfile.recreate_check_signal = USR1
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::SimpleLayout
);

Log::Log4perl->init(\$data);
ok(! -f "${testfile}_4");

$log = Log::Log4perl::get_logger("");
$log->info("File1");

open FILE, "<${testfile}_4" or die "Cannot open ${testfile}_4";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - File1\n");

unlink "${testfile}_4";

#########################################################
# Print a header into a newly opened file
#########################################################
$data = qq(
log4perl.category         = DEBUG, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = ${testfile}_5
log4perl.appender.Logfile.header_text = This is a nice header.
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::SimpleLayout
);

Log::Log4perl->init(\$data);
open FILE, "<${testfile}_5" or die "Cannot open ${testfile}_5";
$content = join '', <FILE>;
close FILE;

is($content, "This is a nice header.\n", "header_text");

reset_logger();
# same with syswrite
$data = qq(
log4perl.category         = DEBUG, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = ${testfile}_6
log4perl.appender.Logfile.header_text = This is a nice header.
log4perl.appender.Logfile.syswrite = 1
log4perl.appender.Logfile.mode=write
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::SimpleLayout
);

Log::Log4perl->init(\$data);
Log::Log4perl->get_logger->debug( "waah!" );
open FILE, "<", "${testfile}_6" or die "Cannot open ${testfile}_6";
$content = join '', <FILE>;
close FILE;

is($content, "This is a nice header.\nDEBUG - waah!\n", "header_text");

####################################################
# Create path if it is not already created
####################################################

my $testmkpathfile = File::Spec->catfile($testpath, "test26.log");

$data = <<EOT;
log4j.category = INFO, FileAppndr
log4j.appender.FileAppndr          = Log::Log4perl::Appender::File
log4j.appender.FileAppndr.filename = $testmkpathfile
log4j.appender.FileAppndr.layout   = Log::Log4perl::Layout::SimpleLayout
log4j.appender.FileAppndr.mkpath   = 1
EOT

Log::Log4perl::init(\$data);
$log = Log::Log4perl::get_logger("");
$log->info("Shu-wa-chi!");

open FILE, "<$testmkpathfile" or die "Cannot create $testmkpathfile";
$content = join '', <FILE>;
close FILE;

is($content, "INFO - Shu-wa-chi!\n");

####################################################
# Create path with umask if it is not already created
####################################################

SKIP: {
  skip "Umask not supported on Win32", 3 if is_like_windows();
  my $oldumask = umask;
  $testmkpathfile = File::Spec->catfile("${testpath}_1", "test26.log");
  $data = <<EOT;
  log4j.category = INFO, FileAppndr
  log4j.appender.FileAppndr              = Log::Log4perl::Appender::File
  log4j.appender.FileAppndr.filename     = $testmkpathfile
  log4j.appender.FileAppndr.layout       = Log::Log4perl::Layout::SimpleLayout
  log4j.appender.FileAppndr.umask        = 0026
  log4j.appender.FileAppndr.mkpath       = 1
  log4j.appender.FileAppndr.mkpath_umask = 0027
EOT
  Log::Log4perl::init(\$data);
  $log = Log::Log4perl::get_logger("");
  $log->info("Shu-wa-chi!");
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat("${testpath}_1");
  is($mode & 0777,0750); #Win32 777
   ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($testmkpathfile);
  is($mode & 07777,0640); #Win32 666
  is(umask,$oldumask);
};

reset_logger();

done_testing;

sub reset_logger {
  local $Log::Log4perl::Config::CONFIG_INTEGRITY_CHECK = 0; # to close handles and allow temp files to go
  Log::Log4perl::init(\'');
}
