###########################################
# Tests for Log4perl::DateFormat
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use warnings;
use strict;

use Test;

BEGIN { plan tests => 11 }

use Log::Log4perl::DateFormat;

###########################################
# Year
###########################################
my $formatter = Log::Log4perl::DateFormat->new("yyyy yy yyyy");
ok($formatter->format(1030429942), "2002 02 2002");

###########################################
# Month
###########################################
$formatter = Log::Log4perl::DateFormat->new("MM M MMMM yyyy");
ok($formatter->format(1030429942), "08 8 August 2002");

###########################################
# Day-of-Month
###########################################
$formatter = Log::Log4perl::DateFormat->new("d ddd dd dddd yyyy");
ok($formatter->format(1030429942), "26 026 26 0026 2002");

###########################################
# am/pm Hour
###########################################
$formatter = Log::Log4perl::DateFormat->new("h hh hhh hhhh");
ok($formatter->format(1030429942), "11 11 011 0011");

###########################################
# 24 Hour
###########################################
$formatter = Log::Log4perl::DateFormat->new("H HH HHH HHHH");
ok($formatter->format(1030429942), "23 23 023 0023");

###########################################
# Minute
###########################################
$formatter = Log::Log4perl::DateFormat->new("m mm mmm mmmm");
ok($formatter->format(1030429942), "32 32 032 0032");

###########################################
# Second
###########################################
$formatter = Log::Log4perl::DateFormat->new("s ss sss ssss");
ok($formatter->format(1030429942), "22 22 022 0022");

###########################################
# Day of Week
###########################################
$formatter = Log::Log4perl::DateFormat->new("E EE EEE EEEE");
ok($formatter->format(1030429942), "Monday Monday Monday Monday");

###########################################
# Day of Year
###########################################
$formatter = Log::Log4perl::DateFormat->new("D DD DDD DDDD");
ok($formatter->format(1030429942), "237 237 237  237");

###########################################
# AM/PM
###########################################
$formatter = Log::Log4perl::DateFormat->new("a aa");
ok($formatter->format(1030429942), "PM PM");

###########################################
# Unknown
###########################################
$formatter = Log::Log4perl::DateFormat->new("xx K");
ok($formatter->format(1030429942), "xx -- 'K' not (yet) implemented --");
