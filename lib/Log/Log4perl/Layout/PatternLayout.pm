##################################################
package Log::Log4perl::Layout::PatternLayout;
##################################################
# TODO: 'd', 't', 'x', 'X'
# lib4j PatternLayout as documented in
# http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html
##################################################

use 5.006;
use strict;
use warnings;
use Log::Log4perl::Level;
use Log::Log4perl::DateFormat;

our $TIME_HIRES_AVAILABLE;
our $TIME_HIRES_AVAILABLE_WARNED = 0;
our $PROGRAM_START_TIME;

BEGIN {
    # Check if we've got Time::HiRes. If not, don't make a big fuss,
    # just set a flag so we know later on that we can't have fine-grained
    # time stamps
    $TIME_HIRES_AVAILABLE = 0;
    eval { require Time::HiRes; };
    if($@) {
        $PROGRAM_START_TIME = time();
    } else {
        $TIME_HIRES_AVAILABLE = 1;
        $PROGRAM_START_TIME = [Time::HiRes::gettimeofday()];
    }
}

use base qw(Log::Log4perl::Layout);

no strict qw(refs);


##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my ($data) = @_;

    my ($layout_string);
     
    if (ref $data){
        $layout_string = $data->{ConversionPattern}{value};
    }else{
        $layout_string = $data;
    }

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;

    $self->define($layout_string);

    return $self;
}



##################################################
sub define {
##################################################
    my($self, $format) = @_;

    # Parse the format
    $format =~ s/%(-*\d*)
                       ([cCdfFILmMnprtxX%])
                       (?:{(.*?)})*/
                       rep($self, $1, $2, $3);
                      /gex;

    $self->{printformat} = $format;
}

##################################################
sub rep {
##################################################
    my($self, $num, $op, $curlies) = @_;

    return "%%" if $op eq "%";

    # If it's a %d{...} construct, initialize a simple date
    # format formatter, so that we can quickly render later on.
    my $sdf;
    if($op eq "d" and defined $curlies) {
        $sdf = Log::Log4perl::DateFormat->new($curlies);
    }

    push @{$self->{stack}}, [$op, $sdf || $curlies];

    $self->{info_needed}->{$op}++;

    return "%${num}s";
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

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
        my ($package, $filename, $line, 
            $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, 
            $hints, $bitmask) = caller($caller_level);

        $info{L} = $line;
        $info{F} = $filename;
        $info{C} = $package;

        if($self->{info_needed}->{M} or
           $self->{info_needed}->{l} or
           0) {
            # For the name of the subroutine the logger was triggered,
            # we need to go one more level up
            $subroutine = (caller($caller_level+1))[3];
            $subroutine = "main::" unless $subroutine;
            $info{M} = $subroutine;
            $info{l} = "$subroutine $filename ($line)";
        }
    }

    $info{c} = $category;
        # %n means \n only if $message doesn't have a trailing newline already.
    if($message =~ /\n\Z/) {
        $info{n} = "";
    } else {
        $info{n} = "\n";
    }
    $info{p} = $priority;

    if($self->{info_needed}->{r}) {
        if($TIME_HIRES_AVAILABLE) {
            $info{r} = 
                int((Time::HiRes::tv_interval ( $PROGRAM_START_TIME ))*1000);
        } else {
            if(! $TIME_HIRES_AVAILABLE_WARNED) {
                $TIME_HIRES_AVAILABLE_WARNED++;
                # warn "Requested %r pattern without installed Time::HiRes\n";
            }
            $info{r} = time() - $PROGRAM_START_TIME;
        }
    }

    if($self->{info_needed}->{d}) {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
           localtime(time);

        $info{d} = sprintf "%d/%02d/%02d %02d:%02d:%02d",
                           $year + 1900, $mon+1, $mday, 
                           $hour, $min, $sec;
    }

        # As long as they're not implemented yet ..
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
    } elsif($ops eq "d") {
        $data = $curlies->format(time());
    } elsif($ops eq "F") {
        my @parts = split m#/#, $data;
            # Limit it to max curlies entries
        if(@parts > $curlies) {
            splice @parts, 0, @parts - $curlies;
        }
        $data = join '/', @parts;
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

Log::Log4perl::Layout::PatternLayout - Pattern Layout

=head1 SYNOPSIS

  use Log::Log4perl::Layout::PatternLayout;

  my $layout = Log::Log4perl::Layout::PatternLayout->("%d (%F:%L)> %m");

=head1 DESCRIPTION

Creates a pattern layout according to
http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html.
Please check this page for documentation on the various C<%x> format
tags.

C<Log::Log4perl::Layout::PatternLayout> 
is used in connection with the C<Log::Log4perl::Appender> object,
which knows how to access its methods to render a message according
to the given C<printf>-like format.

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
