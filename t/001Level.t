###########################################
# Test Suite for Log::Log4perl::Level
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################

#########################
# change 'tests => 1' to 'tests => last_test_to_print';
#########################
use Test;
BEGIN { plan tests => 10 };
use Log::Log4perl::Level;
BEGIN {
    Log::Log4perl::Level->import("Level");
    Log::Log4perl::Level->import("My::Level");
}
ok(1); # If we made it this far, we're ok.

# Import them into the 'main' namespace;
ok($FATAL < $ERROR);
ok($ERROR < $INFO);
ok($INFO  < $DEBUG);

# Import them into the 'Level' namespace;
ok($Level::FATAL < $Level::ERROR);
ok($Level::ERROR < $Level::INFO);
ok($Level::INFO  < $Level::DEBUG);

# Import them into the 'My::Level' namespace;
ok($My::Level::FATAL < $My::Level::ERROR);
ok($My::Level::ERROR < $My::Level::INFO);
ok($My::Level::INFO  < $My::Level::DEBUG);
