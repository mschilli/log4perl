##################################################
package Log::Log4perl::Layout;
##################################################
# TODO: 'd', 'n' OS-specific, 't', 'x', 'X'

use 5.006;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dump qw(dump);

no strict qw(refs);

our $PROGRAM_START_TIME = [gettimeofday()];

##################################################
sub new {
##################################################
    my($class) = @_;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;
}

##################################################
sub define {
##################################################
    my($self, $format) = @_;

    #print "format: '$format'\n";

    # Parse the format
    while($format =~ s/%(-*\d*)
                       ([cCdfFILmMnprtxX%])
                       (?:{(.*?)})*/
                       rep($self, $1, $2, $3);
                      /gex) {
    }

    #print "printformat: '$format'\n";

    $self->{printformat} = $format;
}

##################################################
sub rep {
##################################################
    my($self, $num, $op, $curlies) = @_;

    return " percent" if $op eq "%";

    push @{$self->{stack}}, [$op, $curlies];

    $self->{info_needed}->{$op}++;

    return "%${num}s";
}

##################################################
sub render {
##################################################
    my($self, $logger, $message, $caller_level) = @_;

    $caller_level = 0 unless defined  $caller_level;

    my %info    = ();
    $info{m}    = $message;

    my @results = ();

    if($self->{info_needed}->{L} or
       $self->{info_needed}->{F} or
       $self->{info_needed}->{C} or
       $self->{info_needed}->{l} or
       $self->{info_needed}->{M} or
       0
      ) {
        my ($p, $f, $l) = caller($caller_level);
        my ($package, $filename, $line, 
            $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, 
            $hints, $bitmask) = caller($caller_level);
        $info{L} = $line;
        $info{F} = $filename;
        $info{C} = $package;
        $info{M} = $subroutine;
        $info{l} = "$subroutine $filename ($line)";
    }

    $info{c} = $logger->{logger_class};
    $info{n} = "\n";
    $info{p} = $logger->level_str();
    $info{r} = int((tv_interval ( $PROGRAM_START_TIME ))*1000);

        # As long as they're not implemented yet ..
    $info{d} = "N/A";
    $info{t} = "N/A";
    $info{x} = "N/A";
    $info{X} = "N/A";

        # Iterate over all info fields on the stack
    for my $e (@{$self->{stack}}) {
        my($op, $curlies) = @$e;
        if(exists $info{$op}) {
            my $result = $info{$op};
            $result = curly_action($op, $curlies, $info{$op}) if $curlies;
            push @results, $result;
        } else {
            warn "Format %'$op' not implemented (yet)";
            push @results, "FORMAT-ERROR";
        }
    }

    return (sprintf $self->{printformat}, @results);
}

##################################################
sub curly_action {
##################################################
    my($ops, $curlies, $data) = @_;

    if($ops eq "c") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "C") {
        $data = shrink_category($data, $curlies);
    }

    return $data;
}

##################################################
sub shrink_category {
##################################################
    my($category, $len) = @_;

    my @components = split /\.|::/, $category;

    if(@components > $len) {
        splice @components, 0, @components - $len;
        $category = join '.', @components;
    } 

    return $category;
}

1;

__END__

=head1 NAME

Log::Log4perl::Layout - Log layout

=head1 SYNOPSIS

  use Log::Log4perl::Layout;

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
