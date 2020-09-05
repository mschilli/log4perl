###########################################
# Test DBI appender with SQLite
###########################################

our $table_name = "log4perltest$$";

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Test::More;
use Log::Log4perl;
use warnings;
use strict;
use File::Spec;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir min_version);

BEGIN {
    min_version(qw( DBI DBD::SQLite ));
    plan tests => 3;
}

my $testdir = tmpdir();

my $dbfile = "$testdir/sqlite.dat";

require DBI;

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");

  # https://rt.cpan.org/Public/Bug/Display.html?id=79960
  # undef as NULL
my $stmt = <<EOL;
    CREATE TABLE $table_name (
      loglevel  char(9) ,   
      message   char(128),
      mdc       char(16)
  )
EOL

$dbh->do($stmt) || die "do failed on $stmt".$dbh->errstr;

my $config = <<"EOT";
log4j.category = WARN, DBAppndr
log4j.appender.DBAppndr            = Log::Log4perl::Appender::DBI
log4j.appender.DBAppndr.datasource = dbi:SQLite:dbname=$dbfile
log4j.appender.DBAppndr.sql = \\
   insert into $table_name \\
   (loglevel, mdc, message) \\
   values (?, ?, ?)
log4j.appender.DBAppndr.params.1 = %p    
log4j.appender.DBAppndr.params.2 = %X{foo}
#---------------------------- #3 is message

log4j.appender.DBAppndr.usePreparedStmt=2
log4j.appender.DBAppndr.warp_message=0
    
  #noop layout to pass it through
log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::NoopLayout
EOT

Log::Log4perl::init(\$config);

my $logger = Log::Log4perl->get_logger();
$logger->warn('test message');

my $ary_ref = $dbh->selectall_arrayref( "SELECT * from $table_name" );
is $ary_ref->[0]->[0], "WARN", "level logged in db";
is $ary_ref->[0]->[1], "test message", "msg logged in db";
is $ary_ref->[0]->[2], undef, "msg logged in db";
