##################################################
package Log::Log4perl::Filter::StringMatch;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Config;

use constant DEBUG => 0;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
     my ($class, %options) = @_;

     print join('-', %options) if DEBUG;

     my $self = { StringToMatch => '',
                  AcceptOnMatch => 1,
                  %options,
                };
     
     $self->{AcceptOnMatch} = Log::Log4perl::Config::boolean_to_perlish(
                                                 $self->{AcceptOnMatch});

     $self->{StringToMatch} = qr($self->{StringToMatch});

     bless $self, $class;

     return $self;
}

##################################################
sub decide {
##################################################
     my ($self, %p) = @_;

     local($_) = join $
                     Log::Log4perl::JOIN_MSG_ARRAY_CHAR, @{$p{message}};

     if($_ =~ $self->{StringToMatch}) {
         print "Strings match\n" if DEBUG;
         return $self->{AcceptOnMatch};
     } else {
         print "Strings don't match ($_/$self->{StringToMatch})\n" if DEBUG;
         return !$self->{AcceptOnMatch};
     }
}

1;

__END__

=head1 NAME

Log::Log4perl::Filter::StringMatch - Filter to match the log level exactly

=head1 SYNOPSIS

    log4perl.filter.Match1               = Log::Log4perl::Filter::StringMatch
    log4perl.filter.Match1.StringToMatch = blah blah
    log4perl.filter.Match1.AcceptOnMatch = true

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>, 2003

=cut
