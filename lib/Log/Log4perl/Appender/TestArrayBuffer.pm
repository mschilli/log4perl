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
