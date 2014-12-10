use strict;
use warnings;

my $logfile = "./file.log";
END { unlink $logfile; }

use Log::Log4perl;
use Log::Log4perl::Appender;
use Log::Log4perl::Appender::TestBuffer;
use Log::Log4perl::Layout::PatternLayout;

use Test::More tests => 4;

my $logger = Log::Log4perl->get_logger("blah");

my $appender = Log::Log4perl::Appender->new(
    "Log::Log4perl::Appender::TestBuffer",
        name => 'testbuffer',
);
$logger->add_appender($appender);

my $msg = "line1\nline2\nline3\n";
my $logit = sub {
    $appender->log({ level => 1, message => $msg }, 'foo_category', 'INFO');
};

# indent=fix
my $layout = Log::Log4perl::Layout::PatternLayout->new("%m{indent=2}");
$appender->layout($layout);
$logit->();
is $appender->buffer(), "line1\n  line2\n  line3\n  ", "indent=2";
$appender->buffer("");

# indent=fix,chomp
$layout = Log::Log4perl::Layout::PatternLayout->new("%m{indent=2,chomp}");
$appender->layout($layout);
$logit->();
is $appender->buffer(), "line1\n  line2\n  line3", "indent=2,chomp";
$appender->buffer("");

# indent=variable
$layout = Log::Log4perl::Layout::PatternLayout->new("123%m{indent}");
$appender->layout($layout);
$logit->();
is $appender->buffer(), "123line1\n   line2\n   line3\n   ", "indent";
$appender->buffer("");

# indent=variable,chomp
$layout = Log::Log4perl::Layout::PatternLayout->new("123%m{indent,chomp}");
$appender->layout($layout);
$logit->();
#print "[", $appender->buffer(), "]\n";
is $appender->buffer(), "123line1\n   line2\n   line3", "indent,chomp";
$appender->buffer("");
