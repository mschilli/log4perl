###############r###################################
package Log::Log4perl::Level;
##################################################

use 5.006;
use strict;
use warnings;
use Carp;

no strict qw(refs);

our %PRIORITY = (
    "FATAL" => 0,
    "ERROR" => 3,
    "WARN"  => 4,
    "INFO"  => 6,
    "DEBUG" => 7,
);

    # Reverse mapping
our %LEVELS = map { $PRIORITY{$_} => $_ } keys %PRIORITY;

    # Min and max
$PRIORITY{'OFF'} = $PRIORITY{'FATAL'};
$PRIORITY{'ALL'} = $PRIORITY{'DEBUG'};

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

    for my $key (keys %PRIORITY) {
        my $name  = "$namespace$key";
        my $value = $PRIORITY{$key};
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
sub to_priority {
# changes a level name string to a priority numeric
##################################################
    my($string) = @_;

    if(exists $PRIORITY{$string}) {
        return $PRIORITY{$string};
    }else{
        die "level '$string' is not a valid error level (".join ('|', keys %PRIORITY),')';
    }
}

##################################################
sub to_level {
# changes a priority numeric constant to a level name string 
##################################################
    my ($priority) = @_;
    if (exists $LEVELS{$priority}) {
        return $LEVELS{$priority}
    }else {
        die "priority '$priority' is not a valid error level number (".join ('|', keys %LEVELS),')';
    }
}

##################################################
sub to_LogDispatch_string {
# translates into strings that Log::Dispatch recognizes
##################################################
    my($priority) = @_;

    confess "do what? no priority?" unless defined $priority;

    my $string;

    if(exists $LEVELS{$priority}) {
        $string = $LEVELS{$priority};
    }

        # Log::Dispatch idiosyncrasies
    if($priority == $PRIORITY{WARN}) {
        $string = "WARNING";
    }
         
    if($priority == $PRIORITY{FATAL}) {
        $string = "EMERGENCY";
    }
         
    return $string;
}

###################################################
sub is_valid {
###################################################
    return $LEVELS{$_[0]};
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
