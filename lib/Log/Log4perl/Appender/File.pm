##################################################
package Log::Log4perl::Appender::File;
##################################################

use warnings;
use strict;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name      => "unknown name",
        autoflush => 1,
        mode      => "append",
        @options,
    };

    die "Mandatory parameter 'filename' missing" unless
        exists $self->{filename};

    my $arrows = ">";

    if($self->{mode} eq "append") {
        $arrows = ">>";
    }

    open FH, "$arrows$self->{filename}" or
        die "Can't open $self->{filename} ($@)";

    $self->{fh} = \*FH;

    bless $self, $class;
}
    
##################################################
sub log {
##################################################
    my($self, %params) = @_;

    my $fh = $self->{fh};

    print $fh $params{message};

    if ($self->{autoflush}) {
        my $oldfh = select $self->{fh}; 
        $| = 1; 
        select $oldfh;
    }
}

##################################################
sub DESTROY {
##################################################
    my($self) = @_;

    if ($self->{fh}) {
        my $fh = $self->{fh};
        close $fh;
    }
}

1;

__END__

=head1 NAME

Log::Log4perl::Appender::File - Log to file

=head1 SYNOPSIS

    use Log::Log4perl::Appender::File;

    my $app = Log::Log4perl::Appender::File->new(
      filename  => 'file.log',
      mode      => 'append',
      autoflush => 1,
    );

    $file->log(message => "Log me\n");

=head1 DESCRIPTION

This is a simple appender for writing to a file. 

The constructor C<new()> opens a file, specified in C<filename>, for
writing. If C<mode> is C<append>, it will append to the file if it
exists, on other settings of C<mode> it will clobber any existing
file first. The default C<mode> is C<append>.

C<autoflush>, if set to a true value, triggers flushing the data
out to the file on every call to C<log()>.

The C<log()> method takes a single scalar. If a newline character
should terminate the message, it has to be added explicitely.

Upon destruction of the object, the filehandle to access the
file is flushed and closed.

Design and implementation of this module has been greatly inspired by
Dave Rolsky's C<Log::Dispatch> appender framework.

=head1 AUTHOR

Mike Schilli <log4perl@perlmeister.com>, 2003

=cut
