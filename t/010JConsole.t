use Log::Log4perl;
use Log::Log4perl::TestBuffer;
use Log::Dispatch::File;
use Test;

my $WORK_DIR = 't/tmp';
our @outfiles = ("$WORK_DIR/test1.log",);
unless (-e "$WORK_DIR"){
    mkdir "$WORK_DIR" || die "can't create $WORK_DIR $!";
}
foreach my $f (@outfiles){
    unlink $f if (-e $f);
}


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
use vars qw($OLDOUT); #for -w
open(OLDOUT, ">&STDOUT");
`touch $WORK_DIR/test1.log`;
open(STDOUT, ">$WORK_DIR/test1.log") || die "Can't redirect stdout $WORK_DIR/test1.log $!";
select(STDOUT); $| = 1;     # make unbuffered



$logger->debug("debugging message 1 ");
$logger->info("info message 1 ");      
$logger->warn("warning message 1 ");   
$logger->fatal("fatal message 1 ");   


close(STDOUT);
open(STDOUT, ">&OLDOUT");


my ($result, $expected);

$expected = <<EOL;
INFO  cat1 - info message 1 
WARN  cat1 - warning message 1 
FATAL cat1 - fatal message 1 
EOL

{local $/ = undef;
 open (F, "$WORK_DIR/test1.log") || die $!;
 $result = <F>;
 close F;
}
ok ($result, $expected);



BEGIN { plan tests => 1, }



foreach my $f (@outfiles){
    unlink $f if (-e $f);
}

