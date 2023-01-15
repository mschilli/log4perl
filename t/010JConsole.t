BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Log::Log4perl;
use Log::Log4perl::Appender::TestBuffer;
use Log::Log4perl::Appender::File;
use File::Spec;
use Test::More;
use lib File::Spec->catdir(qw(t lib));
use Log4perlInternalTest qw(tmpdir);

our $LOG_DISPATCH_PRESENT = 0;

BEGIN { 
    eval { require Log::Dispatch; };
    if($@) {
       plan skip_all => "only with Log::Dispatch";
    } else {
       $LOG_DISPATCH_PRESENT = 1;
       plan tests => 1;
    }
};

my $WORK_DIR = tmpdir();
my $test_logfile = File::Spec->catfile($WORK_DIR,'test1.log');

my $conf = <<CONF;
log4j.category.cat1      = INFO, myAppender

log4j.appender.myAppender=org.apache.log4j.ConsoleAppender
log4j.appender.myAppender.Target=System.out
log4j.appender.myAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.myAppender.layout.ConversionPattern=%-5p %c - %m%n
CONF

Log::Log4perl->init(\$conf);

my $logger = Log::Log4perl->get_logger('cat1');

#hmm, I wonder how portable this is, maybe check $^O first?
open(OLDOUT, ">&", STDOUT) or die;
open (TOUCH, ">>", $test_logfile);# `touch $test_logfile`;
close TOUCH;
open(STDOUT, ">", $test_logfile) or die "Can't redirect stdout $test_logfile $!";
select(STDOUT); $| = 1;     # make unbuffered

$logger->debug("debugging message 1 ");
$logger->info("info message 1 ");      
$logger->warn("warning message 1 ");   
$logger->fatal("fatal message 1 ");   

close(STDOUT);
open(STDOUT, ">&", OLDOUT);

my ($result, $expected);

$expected = <<EOL;
INFO  cat1 - info message 1 
WARN  cat1 - warning message 1 
FATAL cat1 - fatal message 1 
EOL

{local $/ = undef;
 open (F, "$test_logfile") || die $!;
 $result = <F>;
 close F;
}
my $rc = is ($result, $expected);

if( !$rc ) {
    warn "Failed with Log::Dispatch $Log::Dispatch::VERSION";
}

done_testing;
