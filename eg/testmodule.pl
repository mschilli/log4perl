#!/usr/bin/perl
###########################################
# Test program using TestModule.pm
#
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use warnings;
use strict;

use TestModule;
use Log::Log4perl qw(get_logger);
use Log::Log4perl::Level;

###########################################
# Init logger
###########################################
my $app = Log::Log4perl::Appender->new(
    "Log::Dispatch::Buffer");
my $logger = get_logger('TestModule');
my $layout = Log::Log4perl::Layout::PatternLayout->new("%d> %m %n");
$app->layout($layout);
$logger->add_appender($app);
$logger->level($DEBUG);

###########################################
# Main program
###########################################
my $obj = TestModule->new();
$obj->do_something();

###########################################
# Print what's been logged
###########################################
print $app->buffer();
