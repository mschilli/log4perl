package Log4perlInternalTest;
use strict;
use warnings;

require Exporter;
use File::Temp qw/ tempdir /;
our @EXPORT_OK = qw(
  is_like_windows
  Compare
  tmpdir
  min_version
);
our @ISA    = qw( Exporter );

# We don't require any of these modules for testing, but if they're 
# installed, we require minimal versions.

my %MINVERSION = qw(
    DBI            1.607
    DBD::CSV       0.33
    SQL::Statement 1.20
    DBD::SQLite    0
    Log::Dispatch  0
);
sub min_version {
    my @missing = grep !eval "use $_ $MINVERSION{$_}; 1", @_;
    return if !@missing;
    Test::More::plan(skip_all =>
        "Skipping as not got: " . join ', ', map "$_ $MINVERSION{$_}", @_);
}

# check if we're on non-unixy system
sub is_like_windows {
    if( $^O eq "MSWin32" or
        $^O eq "cygwin"  or
        $^O eq "msys" ) {
        return 1;
    }

    return 0;
}

sub tmpdir {
    tempdir( CLEANUP => 1 );
}

#Lifted this code from Data::Compare by Fabien Tassin fta@sofaraway.org .
#Using it in the XML tests
use Carp;
sub Compare {
  croak "Usage: Data::Compare::Compare(x, y)\n" unless $#_ == 1;
  my $x = shift;
  my $y = shift;

  my $refx = ref $x;
  my $refy = ref $y;

  unless ($refx || $refy) { # both are scalars
    return $x eq $y if defined $x && defined $y; # both are defined
    !(defined $x || defined $y);
  }
  elsif ($refx ne $refy) { # not the same type
    0;
  }
  elsif ($x == $y) { # exactly the same reference
    1;
  }
  elsif ($refx eq 'SCALAR') {
    Compare($$x, $$y);
  }
  elsif ($refx eq 'ARRAY') {
    if ($#$x == $#$y) { # same length
      my $i = -1;
      for (@$x) {
	$i++;
	return 0 unless Compare($$x[$i], $$y[$i]);
      }
      1;
    }
    else {
      0;
    }
  }
  elsif ($refx eq 'HASH') {
    return 0 unless scalar keys %$x == scalar keys %$y;
    for (keys %$x) {
      next unless defined $$x{$_} || defined $$y{$_};
      return 0 unless defined $$y{$_} && Compare($$x{$_}, $$y{$_});
    }
    1;
  }
  elsif ($refx eq 'REF') {
    0;
  }
  elsif ($refx eq 'CODE') {
    1; #changed for log4perl, let's just accept coderefs
  }
  elsif ($refx eq 'GLOB') {
    0;
  }
  else { # a package name (object blessed)
    my ($type) = "$x" =~ m/^$refx=(\S+)\(/o;
    if ($type eq 'HASH') {
      my %x = %$x;
      my %y = %$y;
      Compare(\%x, \%y);
    }
    elsif ($type eq 'ARRAY') {
      my @x = @$x;
      my @y = @$y;
      Compare(\@x, \@y);
    }
    elsif ($type eq 'SCALAR') {
      my $x = $$x;
      my $y = $$y;
      Compare($x, $y);
    }
    elsif ($type eq 'GLOB') {
      0;
    }
    elsif ($type eq 'CODE') {
      1; #changed for log4perl, let's just accept coderefs
    }
    else {
      croak "Can't handle $type type.";
    }
  }
}

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

Please contribute patches to the project on Github:

    http://github.com/mschilli/log4perl

Send bug reports or requests for enhancements to the authors via our

MAILING LIST (questions, bug reports, suggestions/patches): 
log4perl-devel@lists.sourceforge.net

Authors (please contact them via the list above, not directly):
Mike Schilli <m@perlmeister.com>,
Kevin Goess <cpan@goess.org>

Contributors (in alphabetical order):
Ateeq Altaf, Cory Bennett, Jens Berthold, Jeremy Bopp, Hutton
Davidson, Chris R. Donnelly, Matisse Enzer, Hugh Esco, Anthony
Foiani, James FitzGibbon, Carl Franks, Dennis Gregorovic, Andy
Grundman, Paul Harrington, Alexander Hartmaier  David Hull, 
Robert Jacobson, Jason Kohles, Jeff Macdonald, Markus Peter, 
Brett Rann, Peter Rabbitson, Erik Selberg, Aaron Straup Cope, 
Lars Thegler, David Viner, Mac Yang.

=head1 LICENSE

Copyright 2002-2013 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

