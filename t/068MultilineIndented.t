
use Log::Log4perl;
use Log::Log4perl::Appender;
use Log::Log4perl::Appender::File;
use Log::Log4perl::Layout::PatternLayout::MultilineIndented;

use Test::More tests => 1;

my $logger = Log::Log4perl->get_logger("blah");

#      1                 19
#      |                 |
# %d : yyyy/mm/dd hh:mm:ss
my $layout = Log::Log4perl::Layout::PatternLayout::MultilineIndented->new("%d > %m%n");

my $logfile = "./file.log";

my $appender = Log::Log4perl::Appender->new(
               "Log::Log4perl::Appender::File",
                    name => 'foo',
                    filename  => './file.log',
                    mode      => 'append',
                    autoflush => 1,
               );

# Set the appender's layout
$appender->layout($layout);
$logger->add_appender($appender);

my $msg =<<"EOF_MSG";
This is
a message with
multiple lines
EOF_MSG

chomp($msg);

$appender->log({ level => 1, message => $msg }, 'foo_category', 'INFO');

my $err_str = check_log_file_format($logfile);
my $test_name = 'log file has multiline intended format' . ($err_str ? " - reason : $err_str" : "");
ok ( ! $err_str, $test_name );


unlink $logfile;


sub check_log_file_format {
    my $logfile = shift;
    
    my $err_str = "";
    my $line_count = 1;
    open(my $fh, "<", $logfile) || return "could not open log file '$logfile'";

    for my $line (<$fh>) {
        if ($line_count == 1) {
            # 1                 19 
            # |                 |
            # yyyy/mm/dd hh:mm:ss > %m
            unless ( $line =~ m!^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} > This is\s*$! ) {
                $err_str = "first line wrong, should be: yyyy/mm/dd hh::mm::ss This is" ;        
                last;
            }
        }
        else {
            unless ( $line =~ /^ {22}\S/ ) {
                $err_str = "format of line $line_count wrong";
                last;
            }
        }
        $line_count++;
    }

    close($fh);

    return $err_str;
}
