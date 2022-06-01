###########################################
# Test using Log::Dispatch::DBI
# Kevin Goess <cpan@goess.org>
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
use strict;
use warnings;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir min_version);

BEGIN {
    min_version(qw( DBI DBD::CSV SQL::Statement ));
}

require DBI;
my $WORK_DIR = tmpdir();
my $dbh = DBI->connect('DBI:CSV:f_dir='.$WORK_DIR,'testuser','testpw',{ RaiseError => 1, PrintError => 1 });

my $stmt = <<EOL;
    CREATE TABLE $table_name (
      loglevel     char(9) ,
      message   char(128),
      shortcaller   char(5),
      thingid    char(6),
      category  char(16),
      pkg    char(16),
      runtime1 char(16),
      runtime2 char(16)
  )
EOL

$dbh->do($stmt);

#creating a log statement where bind values 1,3,5 and 6 are
#calculated from conversion specifiers and 2,4,7,8 are
#calculated at runtime and fed to the $logger->whatever(...)
#statement

my $config = <<"EOT";
#log4j.category = WARN, DBAppndr, console
log4j.category = WARN, DBAppndr
log4j.appender.DBAppndr             = Log::Log4perl::Appender::DBI
log4j.appender.DBAppndr.datasource = DBI:CSV:f_dir=$WORK_DIR
log4j.appender.DBAppndr.username  = bobjones
log4j.appender.DBAppndr.password = 12345
log4j.appender.DBAppndr.sql = \\
   insert into $table_name \\
   (loglevel, message, shortcaller, thingid, category, pkg, runtime1, runtime2) \\
   values (?,?,?,?,?,?,?,?)
log4j.appender.DBAppndr.params.1 = %p
#---------------------------- #2 is message
log4j.appender.DBAppndr.params.3 = %5.5l
#---------------------------- #4 is thingid
log4j.appender.DBAppndr.params.5 = %c
log4j.appender.DBAppndr.params.6 = %C
#-----------------------------#7,8 are also runtime

log4j.appender.DBAppndr.bufferSize=2
log4j.appender.DBAppndr.warp_message=0

#noop layout to pass it through
log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::NoopLayout

#a console appender for debugging
log4j.appender.console = Log::Log4perl::Appender::Screen
log4j.appender.console.layout = Log::Log4perl::Layout::SimpleLayout


EOT

Log::Log4perl::init(\$config);


# *********************
# check a category logger

my $logger = Log::Log4perl->get_logger("groceries.beer");

$logger->fatal('fatal message',1234,'foo',{aaa => 'aaa'});

#since we ARE buffering, that message shouldnt be there yet
my $file = File::Spec->catfile($WORK_DIR, $table_name);
SKIP: {
 skip 'no file is fine', 1 if !-f $file;
 my $got = read_table($file);
 my $expected = <<EOL;
LOGLEVEL,MESSAGE,SHORTCALLER,THINGID,CATEGORY,PKG,RUNTIME1,RUNTIME2
EOL
  $expected =~ s/[^\w ,"()]//g;
  $expected = lc $expected;
  is($got, $expected, "buffered");
}

$logger->warn('warning message',3456,'foo','bar');

#with buffersize == 2, now they should write
{
my $sth = $dbh->prepare("select * from $table_name");
$sth->execute;
my $got = $sth->fetchrow_arrayref;
is_deeply [ @$got[0..6] ], [ 'FATAL', "fatal message", 'main:', 1234, 'groceries.beer', 'main', 'foo' ];
$got = $sth->fetchrow_arrayref;
is_deeply $got, [ 'WARN', "warning message", 'main:', 3456, 'groceries.beer', 'main', 'foo', 'bar' ], "buffersize=2" or diag explain $got;
}


# setting is WARN so the debug message should not go through
$logger->debug('debug message',99,'foo','bar');
$logger->warn('warning message with two params',99, 'foo', 'bar');
$logger->warn('another warning to kick the buffer',99, 'foo', 'bar');

my $sth = $dbh->prepare("select * from $table_name");
$sth->execute;

#first two rows are repeats from the last test
my $row = $sth->fetchrow_arrayref;
is_deeply [ @$row[0..6] ], [ 'FATAL', "fatal message", 'main:', 1234, 'groceries.beer', 'main', 'foo' ];
like $row->[7], qr/HASH/, 'verifying param checking for "filter=>sub{...}" stuff';

$row = $sth->fetchrow_arrayref;
is_deeply $row, [ 'WARN', 'warning message', 'main:', '3456', 'groceries.beer', 'main', 'foo', 'bar' ];

#these two rows should have undef for the final two params
$row = $sth->fetchrow_arrayref;
is_deeply $row, [ 'WARN', 'warning message with two params', 'main:', 99, 'groceries.beer', 'main', 'foo', 'bar' ], '2 params';

$row = $sth->fetchrow_arrayref;
is_deeply $row, [ 'WARN', 'another warning to kick the buffer', 'main:', 99, 'groceries.beer', 'main', 'foo', 'bar' ], 'kick';

#that should be all
ok !$sth->fetchrow_arrayref, 'no more';

$dbh->do("DROP TABLE $table_name");
$dbh->disconnect;

# **************************************
# checking usePreparedStmt, spurious warning bug reported by Brett Rann
# might as well give it a thorough check
Log::Log4perl->reset;

reset_logger();

$dbh = DBI->connect('DBI:CSV:f_dir='.$WORK_DIR,'testuser','testpw',{ PrintError => 1 });

$stmt = <<EOL;
    CREATE TABLE $table_name (
      loglevel     char(9) ,
      message   char(128)

  )
EOL

$dbh->do($stmt) || die "do failed on $stmt".$dbh->errstr;


$config = <<"EOT";
log4j.category = WARN, DBAppndr
log4j.appender.DBAppndr             = Log::Log4perl::Appender::DBI
log4j.appender.DBAppndr.datasource = DBI:CSV:f_dir=$WORK_DIR
log4j.appender.DBAppndr.sql = \\
   insert into $table_name \\
   (loglevel, message) \\
   values (?,?)
log4j.appender.DBAppndr.params.1 = %p
#---------------------------- #2 is message

log4j.appender.DBAppndr.usePreparedStmt=2
log4j.appender.DBAppndr.warp_message=0

#noop layout to pass it through
log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::NoopLayout

EOT

Log::Log4perl::init(\$config);

$logger = Log::Log4perl->get_logger("groceries.beer");

$logger->fatal('warning message');

#since we're not buffering, this message should show up immediately
{
my $sth = $dbh->prepare("select * from $table_name");
$sth->execute;
my $got = $sth->fetchrow_arrayref;
is_deeply $got, [ 'FATAL',"warning message" ], 'unbuffered shows immediately' or diag explain $got;
}

$logger->fatal('warning message');

  # https://rt.cpan.org/Public/Bug/Display.html?id=79960
  # undef as NULL
$dbh->do("DROP TABLE $table_name");

$stmt = <<EOL;
    CREATE TABLE $table_name (
      loglevel     char(9) ,
      message   char(128),
      mdc char(16)

  )
EOL

$dbh->do($stmt) || die "do failed on $stmt".$dbh->errstr;

$config = <<"EOT";
log4j.category = WARN, DBAppndr
log4j.appender.DBAppndr             = Log::Log4perl::Appender::DBI
log4j.appender.DBAppndr.datasource = DBI:CSV:f_dir=$WORK_DIR
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

$logger = Log::Log4perl->get_logger();
$logger->warn('test message');

{
my $sth = $dbh->prepare("select * from $table_name");
$sth->execute;
my $got = $sth->fetchrow_arrayref;
is_deeply $got, [ 'WARN', "test message", '' ], "dbi insert with NULL values" or diag explain $got;
}

reset_logger();
done_testing;

sub reset_logger {
  local $Log::Log4perl::Config::CONFIG_INTEGRITY_CHECK = 0; # to close handles and allow temp files to go
  Log::Log4perl::init(\'');
}

sub read_table {
  my ($file) = @_;
  my $got = do {local $/; open my $f, $file or die "$file: $!"; <$f>};
  $got =~ s/[^\w ,"()]//g;  #silly DBD_CSV uses funny EOL chars
  lc $got;
}
