##################################################
package Log::Log4perl::Appender::TestArrayBuffer;
##################################################
# Like Log::Log4perl::Appender::TestBuffer, just with 
# array capability.
# For testing only.
##################################################

use Params::Validate qw(validate SCALAR ARRAYREF CODEREF);

use base qw( Log::Log4perl::Appender::TestBuffer );

##################################################
# overriding superclass so we can get arrayrefs 
# through in 'message'
##################################################
sub log
{
    my $self = shift;

    my %p = validate( @_, { level => { type => SCALAR },
                            message => {  },
                            log4p_level => { type => SCALAR },
                            log4p_category  => { type => SCALAR },
                            name  => { type => SCALAR },
                          } );

    return unless $self->_should_log($p{level});

    $p{message} = $self->_apply_callbacks(%p)
        if $self->{callbacks};

    $self->log_message(%p);
}

##################################################
sub log_message {   
##################################################
    my $self = shift;
    my %params = @_;

    $self->{buffer} .= "[$params{level}]: " if $LOG_PRIORITY;

    if(ref($params{message}) eq "ARRAY") {
        $self->{buffer} .= "[" . join(',', @{$params{message}}) . "]";
    } else {
        $self->{buffer} .= $params{message};
    }
}

1;

=head1 NAME

Log::Log4perl::Appender::TestArrayBuffer - Subclass of Appender::TestBuffer

=head1 SYNOPSIS

  use Log::Log4perl::Appender::TestArrayBuffer;

  my $appender = Log::Log4perl::Appender::TestArrayBuffer->new( 
      name      => 'buffer',
      min_level => 'debug',
      );

      # Append to the buffer
  $appender->log_message( 
      level =  > 'alert', 
      message => ['first', 'second', 'third'],
      );

      # Retrieve the result
  my $result = $appender->buffer();

      # Reset the buffer to the empty string
  $appender->reset();

=head1 DESCRIPTION

This class is a subclass of Log::Log4perl::Appender::TestBuffer and
just provides message array refs as an additional feature. 

Just like Log::Log4perl::Appender::TestBuffer, 
Log::Log4perl::Appender::TestArrayBuffer is used for internal
Log::Log4perl testing only.

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
