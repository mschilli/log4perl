##################################################
package Log::Log4perl::Appender::Socket;
##################################################

use warnings;
use strict;

use IO::Socket::INET;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name      => "unknown name",
        type      => SOCK_STREAM,
        timeout   => 5,
        @options,
    };

    $self->{socket} = IO::Socket::INET->new(@options);
    $self->{socket}->autoflush(1);

    bless $self, $class;
}
    
##################################################
sub log {
##################################################
    my($self, %params) = @_;

    $self->{socket}->send($params{message});
    $self->{socket}->flush();

}

##################################################
sub DESTROY {
##################################################
    my($self) = @_;

    undef $self->{socket};
}

1;

__END__

=head1 NAME

Log::Log4perl::Appender::Socket - Log to a socket

=head1 SYNOPSIS

    use Log::Log4perl::Appender::Socket;

    my $app = Log::Log4perl::Appender::Socket->new(
      PeerHost => "server.foo.com",
      PeerPort => 1234,
    );

    $file->log(message => "Log me\n");

=head1 DESCRIPTION

This is a simple appender for writing to a socket. It relies on
L<IO::Socket::INET> and offers all parameters this module offers.

Upon destruction of the object, pending messages will be flushed
and the socket will be closed.

=head1 AUTHOR

Mike Schilli <log4perl@perlmeister.com>, 2003

=cut
