package Log::Log4perl::Internal::Test;
use strict;
use warnings;

# We don't require any of these modules for testing, but if they're 
# installed, we require minimal versions.

our %MINVERSION = qw(
    DBI            1.607
    DBD::CSV       0.33
    SQL::Statement 1.20
);

1;

__END__

=head1 NAME

Log::Log4perl::Internal::Test - Internal Test Utilities for Log4perl

=head1 SYNOPSIS

    use Log::Log4perl::Internal::Test;

=head1 DESCRIPTION

Some general-purpose test routines and constants to be used in the Log4perl
test suite.

=head1 AUTHOR

2012, Mike Schilli <cpan@perlmeister.com>
