use Log::Log4perl;
use Test;


$debug = 0;


$testfile = 't/tmp/test12.log';

unlink $testfile if (-e $testfile);


# *****************************************************
# nonexistent appender class
$conf = <<EOL;
log4j.category.simplelayout.test=INFO, myAppender

log4j.appender.myAppender        = Log::Log4perl::Appender::FileAppenderx
log4j.appender.myAppender.layout = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.File   = $testfile
EOL

eval{
    Log::Log4perl->init(\$conf);
};
ok($@,'/ERROR: trying to set appender for myAppender to Log::Log4perl::Appender::FileAppenderx failed/');


# *****************************************************
# nonexistent layout class
$conf = <<EOL;
log4j.category.simplelayout.test=INFO, myAppender

log4j.appender.myAppender        = Log::Log4perl::Appender::FileAppender
log4j.appender.myAppender.layout = Log::Log4perl::Layout::SimpleLayoutx
log4j.appender.myAppender.File   = $testfile
EOL

eval{
    Log::Log4perl->init(\$conf, $debug);
};
ok($@,'/ERROR: trying to set layout for myAppender to Log::Log4perl::Layout::SimpleLayoutx failed/');


# *****************************************************
# bad priority
$conf = <<EOL;
log4j.category.simplelayout.test=xxINFO, myAppender

log4j.appender.myAppender        = Log::Dispatch::File
log4j.appender.myAppender.layout = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.File   = $testfile
EOL

eval{
    Log::Log4perl->init(\$conf, $debug);

};
ok($@,"/level 'xxINFO' is not a valid error level/");



# *****************************************************
# nonsense conf file 1
$conf = <<EOL;
log4j.category.simplelayout.test=INFO, myAppender

log4j.appender.myAppender        = Log::Log4perl::Appender::FileAppender
log4j.appender.myAppender        = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.File   = $testfile
EOL

eval{
    Log::Log4perl->init(\$conf, $debug);
};
ok($@,'/Layout not specified for appender myAppender at/');

# *****************************************************
# nonsense conf file 2
$conf = <<EOL;
log4j.category.simplelayout.test=INFO, myAppender

log4j.appender.myAppender        = Log::Log4perl::Appender::FileAppender
log4j.appender.myAppender.layout = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender        = $testfile
EOL

eval{
    #this warns about errors like
    #Warning: Use of "require" without parens is ambiguous at (eval 9) line 1.
    #Bareword found where operator expected at (eval 9) line 1, near "/tmp/test12::log"
    #    (Missing operator before test12::log?)
    #how to suppress STDERR?

    Log::Log4perl->init(\$conf, $debug);

};
ok($@,"/ERROR:  I don't know how to make a 't/tmp/test12.log' to implement your appender/");



# *****************************************************
# never define an appender
$conf = <<EOL;
log4j.category.simplelayout.test=INFO, XXmyAppender

log4j.appender.myAppender        = Log::Log4perl::Appender::FileAppender
log4j.appender.myAppender.layout = Log::Log4perl::Layout::SimpleLayout
log4j.appender.myAppender.File   = $testfile
EOL

eval{
    Log::Log4perl->init(\$conf, $debug);

};
ok($@,'/Layout not specified for appender XXmyAppender/');



BEGIN { plan tests => 6, }

END{   
     unlink $testfile if (-e $testfile);
}

