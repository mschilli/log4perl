###########################################
# 020Easy2.t - more Easy tests
# Mike Schilli, 2004 (m@perlmeister.com)
###########################################
use warnings;
use strict;

my $stderr = "";

$SIG{__WARN__} = sub {
    #print "warn: <$_[0]>\n";
    $stderr .= $_[0];
};

use Test::More tests => 1;

use Log::Log4perl qw(:easy);

Log::Log4perl->init(\ q{
log4perl.category.Bar.Twix         = WARN, Term
log4perl.appender.Term          = Log::Log4perl::Appender::Screen
log4perl.appender.Term.layout = Log::Log4perl::Layout::SimpleLayout
});

    # This case caused a warning L4p 0.47
INFO "Boo!";

#print "stderr=[$stderr]\n";
is($stderr, "", "no warning");
