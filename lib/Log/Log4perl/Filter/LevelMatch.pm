##################################################
package Log::Log4perl::Filter::LevelMatch;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;

use constant DEBUG => 0;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
     my ($class, %options) = @_;

     my $self = { LevelToMatch  => '',
                  AcceptOnMatch => 1,
                  %options,
                };
     
     $self->{AcceptOnMatch} = Log::Log4perl::Config::boolean_to_perlish(
                                                 $self->{AcceptOnMatch});

     bless $self, $class;

         # Register this bool filter 
         # with the global filter registry
     Log::Log4perl::Filter::by_name($options{name}, $self);

     return $self;
}

##################################################
sub decide {
##################################################
     my ($self, %p) = @_;

     if($self->{LevelToMatch} eq $p{log4p_level}) {
         print "Levels match\n" if DEBUG;
         return $self->{AcceptOnMatch};
     } else {
         print "Levels don't match\n" if DEBUG;
         return !$self->{AcceptOnMatch};
     }
}

1;

__END__

=head1 NAME

Log::Log4perl::Filter::LevelMatch - Filter to match the log level exactly

=head1 SYNOPSIS

    log4perl.filter.Match1               = Log::Log4perl::Filter::LevelMatch
    log4perl.filter.Match1.LevelToMatch  = ERROR
    log4perl.filter.Match1.AcceptOnMatch = true

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>, 2003

=cut
