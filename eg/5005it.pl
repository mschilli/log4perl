#!/usr/bin/perl
###########################################
# 5005it -- make a PM file 5005-compatible
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use 5.00503;
use strict;

use File::Find;

my $USEVARS_DONE = 0;
my @OUR_VARS     = ();

###########################################
sub mk5005 {
###########################################
    find(\&process_file, "lib", "t");
}

###########################################
sub process_file {
###########################################
    my($file) = $_;

    return unless -f $file;

    $USEVARS_DONE = 0;
    @OUR_VARS     = ();
    
    open FILE, "<$file" or die "Cannot open $file";
    my $data = join '', <FILE>;
    close FILE;

    while($data =~ /^our\s+([\$%@][\w_]+).*[;=]/mg) {
        push @OUR_VARS, $1;
    }

        # Replace 'our' variables
    $data =~ s/^our\s+[\$%@][\w_]+.*/rep_our($&)/meg;

        # Replace 'use 5.006' lines
    $data =~ s/^use\s+5\.006/use 5.00503/mg;

        # Delete 'use warnings;'
    $data =~ s/^use warnings;//mg;

    open FILE, ">$file" or die "Cannot open $file";
    print FILE $data;
    close FILE;
}

###########################################
sub rep_our {
###########################################
    my($line) = @_;

    my $out = "";

    if(!$USEVARS_DONE) {
        $out = "use vars qw(" . join(" ", @OUR_VARS) . "); ";
        $USEVARS_DONE = 1;
    }

    if($line =~ /=/) {
            # There's an assignment, just skip the 'our'
        $line =~ s/^our\s+//;
    } else {
            # There's nothing, just get rid of the entire line
        $line = "\n";
    }

    $out .= $line;
    return $out;
}

1;
