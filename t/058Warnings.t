
BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use Test::More;
use Log::Log4perl qw(:nostrict);
my $warnings;

$SIG{__WARN__} = sub {
    $warnings .= $_[0];
};

my $EG_DIR = "eg";
$EG_DIR = "../eg" unless -d $EG_DIR;

Log::Log4perl->init( "$EG_DIR/dupe-warning.conf" );

is($warnings, undef, "no warnings");

done_testing;
