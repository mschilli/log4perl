###########################################
# Tests for Log4perl used by a wrapper class
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use warnings;
use strict;

use Test::More;

BEGIN { plan tests => 4 }

##################################################
package Wrapper::Log4perl;

use Log::Log4perl;
use Log::Log4perl::Level;

our @ISA = qw(Log::Log4perl);

sub get_logger {
    # This is highly stupid (object duplication) and definitely not what we 
    # want anybody to do, but just to have a test case for a logger in a 
    # wrapper package
    return Wrapper::Log4perl::Logger->new(@_);
}

##################################################
package Wrapper::Log4perl::Logger;
Log::Log4perl->wrapper_register(__PACKAGE__);
sub new {
    my $real_logger = Log::Log4perl::get_logger(@_);
    bless { real_logger => $real_logger }, $_[0];
}
sub AUTOLOAD {
    no strict;
    my $self = shift;
    $AUTOLOAD =~ s/.*:://;
    $self->{real_logger}->$AUTOLOAD(@_);
}
sub DESTROY {}

##################################################
package main;

use Log::Log4perl;
local $Log::Log4perl::caller_depth =
    $Log::Log4perl::caller_depth + 1;
use Log::Log4perl::Level;

my $log0 = Wrapper::Log4perl->get_logger("");
$log0->level($DEBUG);

my $app0 = Log::Log4perl::Appender->new(
    "Log::Log4perl::Appender::TestBuffer");
my $layout = Log::Log4perl::Layout::PatternLayout->new(
    "File: %F{1} Line number: %L package: %C");
$app0->layout($layout);
$log0->add_appender($app0);

##################################################
my $rootlogger = Wrapper::Log4perl->get_logger("");
$rootlogger->debug("Hello");

is($app0->buffer(), "File: 022Wrap.t Line number: 62 package: main",
   "appender check");

##################################################
package L4p::Wrapper;
Log::Log4perl->wrapper_register(__PACKAGE__);
no strict qw(refs);
*get_logger = sub {

    my @args = @_;

    if(defined $args[0] and $args[0] eq __PACKAGE__) {
         $args[0] =~ s/__PACKAGE__/Log::Log4perl/g;
    }
    Log::Log4perl::get_logger( @args );
};

package main;

my $logger = L4p::Wrapper::get_logger();
is $logger->{category}, "main", "cat on () is main";

$logger = L4p::Wrapper::get_logger(__PACKAGE__);
is $logger->{category}, "main", "cat on (__PACKAGE__) is main";

$logger = L4p::Wrapper->get_logger();
is $logger->{category}, "main", "cat on ->() is main";

# use Data::Dumper;
# print Dumper($logger);
