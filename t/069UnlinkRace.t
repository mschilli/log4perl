# Tests to see if an unlink succeeds where it should.
#
# You can work around this by placing the unlink call into an END
# block before the C<< use Log::Log4perl... >> statements are done.
# Once this happens, the END block stack attempts to remove the file
# at a point before the L4P system has released it.  If the
# END{unlink} block is defined before L4P is loaded, then the END
# blocks are unwound in the proper order.  This, however, is fragile.
#
# I have only been able to reproduce this under Win32.
#
# This test script cleans up after itself, even if the test fails.
#

my $logfile = "test.log";
END { unlink $logfile if -f $logfile }

use Log::Log4perl;
use Log::Log4perl::Appender;
use Log::Log4perl::Appender::File;

use Test::More;

BEGIN {
    if(exists $ENV{"L4P_ALL_TESTS"}) {
        plan tests => 1;
    } else {
        plan skip_all => "- only with L4P_ALL_TESTS";
    }
}

Log::Log4perl->init({
   'log4perl.rootLogger'                             => 'ALL, FILE',
   'log4perl.appender.FILE'                          =>
       'Log::Log4perl::Appender::File',
   'log4perl.appender.FILE.filename'                 => sub { "$logfile" },
   'log4perl.appender.FILE.layout'                   => 'SimpleLayout',
});

unlink $logfile;

ok( ! -f $logfile, "logfile was successfully removed" ) or
    diag( "error: $!" ) if $!;
