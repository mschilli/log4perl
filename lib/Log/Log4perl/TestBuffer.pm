package Log::Log4perl::TestBuffer;

##################################################
# Log dispatcher writing to a string buffer
# For testing.
# This is like having a Log::Log4perl::TestBuffer
##################################################

use Log::Dispatch::Output;
use base qw( Log::Dispatch::Output );
use fields qw( stderr );

    # This is a dirty trick for testing: Keep track
    # of the entire object population. So we'll 
    # be able to access the buffers even if the
    # objects are created behind our back -- as
    # long as we remember the order in which
    # they've been created:
    # $Log::Log4perl::TestBuffer::POPULATION[0] is
    # the first one etc.
    # The DESTROY method below cleans up afterwards.

our @POPULATION = ();

##################################################
sub new {
##################################################
    my $proto = shift;
    my $class = ref $proto || $proto;
    my %params = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%params);
    $self->{stderr} = exists $params{stderr} ? $params{stderr} : 1;
    $self->{buffer} = "";

    push @POPULATION, $self;

    return $self;
}

##################################################
sub log_message {   
##################################################
    my $self = shift;
    my %params = @_;

    $self->{buffer} .= $params{message};
}

##################################################
sub buffer {   
##################################################
    my($self, $new) = @_;

    if(defined $new) {
        $self->{buffer} = $new;
    }

    return $self->{buffer};
}

##################################################
sub reset {   
##################################################
    my($self) = @_;

    @POPULATION = ();
    $self->{buffer} = "";
}

##################################################
sub DESTROY {   
##################################################
    my($self) = @_;

    return unless defined $self;

    @POPULATION = grep { defined $_ && $_ != $self } @POPULATION;
}

1;

__END__

=head1 NAME

Log::Log4perl::TestBuffer - Appender class for testing

=head1 SYNOPSIS

  use Log::Log4perl::TestBuffer;

  my $appender = Log::Dispatch::Screen->new( 
      name      => 'buffer',
      min_level => 'debug',
      );

      # Append to the buffer
  $appender->log_message( 
      level =  > 'alert', 
      message => "I'm searching the city for sci-fi wasabi\n" 
      );

      # Retrieve the result
  my $result = $appender->buffer();

      # Reset the buffer to the empty string
  $appender->reset();

=head1 DESCRIPTION

This class is used for internal testing of C<Log::Log4perl>. It
is a C<Log::Dispatch>-style appender, which writes to a buffer 
in memory, from where actual results can be easily retrieved later
to compare with expeced results.

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
