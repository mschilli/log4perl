use Log::Log4perl;
use Test::More;
use File::Spec;

BEGIN {
    eval {
        require Log::Dispatch::FileRotate;
    };
    if ($@) {
        plan skip_all => "only with Log::Dispatch::FileRotate";
    } else {
        plan tests => 2;
    }
}

my $WORK_DIR = "tmp";
if(-d "t") {
    $WORK_DIR = File::Spec->catfile(qw(t tmp));
}
unless (-e "$WORK_DIR"){
    mkdir("$WORK_DIR", 0755) || die "can't create $WORK_DIR ($!)";
}

my $WORK_DIR = File::Spec->catfile(qw(t tmp));
use vars qw(@outfiles); @outfiles = (File::Spec->catfile($WORK_DIR, 'rolltest.log'),
                                     File::Spec->catfile($WORK_DIR, 'rolltest.log.1'),
                                     File::Spec->catfile($WORK_DIR, 'rolltest.log.2'),);

foreach my $f (@outfiles){
    unlink $f if (-e $f);
}


my $conf = <<CONF;
log4j.category.cat1      = INFO, myAppender

log4j.appender.myAppender=org.apache.log4j.RollingFileAppender
log4j.appender.myAppender.File=@{[File::Spec->catfile($WORK_DIR, 'rolltest.log')]}
#this will roll the file after one write
log4j.appender.myAppender.MaxFileSize=15
log4j.appender.myAppender.MaxBackupIndex=2
log4j.appender.myAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.myAppender.layout.ConversionPattern=%-5p %c - %m%n

CONF

Log::Log4perl->init(\$conf);

my $logger = Log::Log4perl->get_logger('cat1');

$logger->debug("debugging message 1 ");
$logger->info("info message 1 ");      
$logger->warn("warning message 1 ");   
$logger->fatal("fatal message 1 ");   



open (F, File::Spec->catfile($WORK_DIR, 'rolltest.log.2'));
my $result = <F>;
close F;
like($result, qr/^INFO  cat1 - info message 1/);

#MaxBackupIndex is 2, so this file shouldn't exist
ok(! -e File::Spec->catfile($WORK_DIR, 'rolltest.log.3'));

foreach my $f (@outfiles){
    unlink $f if (-e $f);
}

