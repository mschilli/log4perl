##################################################
package Log::Log4perl::Level;
##################################################

use 5.006;
use strict;
use warnings;

no strict qw(refs);

our %LEVELS = (
    "FATAL" => 0,
    "ERROR" => 3,
    "WARN"  => 4,
    "INFO"  => 6,
    "DEBUG" => 7,
);

    # Reverse mapping
our %STRINGS = map { $LEVELS{$_} => $_ } keys %LEVELS;

    # Min and max
$LEVELS{'OFF'} = $LEVELS{'FATAL'};
$LEVELS{'ALL'} = $LEVELS{'DEBUG'};

###########################################
sub import {
###########################################
    my($class, $namespace) = @_;
           
    if(defined $namespace) {
        # Export $OFF, $FATAL, $ERROR etc. to
        # the given namespace
        $namespace .= "::" unless $namespace =~ /::$/;
    } else {
        # Export $OFF, $FATAL, $ERROR etc. to
        # the caller's namespace
        $namespace = caller(0) . "::";
    }

    for my $key (keys %LEVELS) {
        my $name  = "$namespace$key";
        my $value = $LEVELS{$key};
        *{"$name"} = \$value;
    }
}

##################################################
sub new { 
##################################################
    # We don't need any of this class nonsense
    # in Perl, because we won't allow subclassing
    # from this. We're optimizing for raw speed.
}

##################################################
sub to_level {
##################################################
    my($string) = @_;

    my $level;

    if(exists $LEVELS{$string}) {
        $level = $LEVELS{$string};
    }
         
    return $level;
}

##################################################
sub to_string {
##################################################
    my($level) = @_;

    my $string;

    if(exists $STRINGS{$level}) {
        $string = $STRINGS{$level};
    }

        # Log::Dispatch idiosyncrasies
    if($level == $LEVELS{WARN}) {
        $string = "WARNING";
    }
         
    if($level == $LEVELS{FATAL}) {
        $string = "EMERGENCY";
    }
         
    return $string;
}

1;

__END__

=head1 NAME

Log::Log4perl::Level - Predefined log levels

=head1 SYNOPSIS

  use Log::Log4perl::Level;

  print $ERROR, "\n";
      # => "3"

=head1 DESCRIPTION

This package simply exports a predefined set of I<Log4perl> log
levels to the caller's name space. After

    use Log::Log4perl::Level;

the following scalar are defined:

    $OFF    => 0
    $FATAL  => 0
    $ERROR  => 3
    $WARN   => 4
    $INFO   => 6
    $DEBUG  => 7
    $ALL    => 7

If the caller wants to import these constants into a different namespace,
it can be provided with the C<use> command:

    use Log::Log4perl::Level qw(Level);

After this C<$Level::ERROR>, C<$Level::INFO> etc. will be defined
accordingly.

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
