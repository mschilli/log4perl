###########################################
# Tests for Log4perl::DateFormat
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use warnings;
use strict;

use Test;

BEGIN { plan tests => 1 }

use Log::Log4perl::DateFormat;

my $formatter = Log::Log4perl::DateFormat->new("yyyy yy yyyy");

ok($formatter->format(1030429942), "2002 02 2002");
