use strict;
use File::Temp qw( tempfile );
use Log::Log4perl qw( get_logger );
use Test::More;

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

eval {
    foo();
};

like $@, qr/main::foo/, "stacktrace on internal error";
done_testing;

sub foo {
    Log::Log4perl::Logger->cleanup();
    my $logger = get_logger();
}
