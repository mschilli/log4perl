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
        umask     => undef,
        autoflush => 1,
        mode      => "append",
        @options,
    };

    die "Mandatory parameter 'filename' missing" unless
        exists $self->{filename};

    bless $self, $class;

        # This will die() if it fails
    $self->file_open();

    return $self;
}

##################################################
sub filename {
##################################################
    my($self) = @_;

    return $self->{filename};
}

##################################################
sub file_open {
##################################################
    my($self) = @_;

    my $arrows = ">";

    my $old_umask = umask();

    if($self->{mode} eq "append") {
        $arrows = ">>";
    } elsif ($self->{mode} eq "pipe") {
        $arrows = "|";
    }

    my $fh = do { local *FH; *FH; };

    umask($self->{umask}) if defined $self->{umask};

    open $fh, "$arrows$self->{filename}" or
        die "Can't open $self->{filename} ($@)";

    umask($old_umask) if defined $self->{umask};

    $self->{fh} = $fh;

    if ($self->{autoflush}) {
        my $oldfh = select $self->{fh}; 
        $| = 1; 
        select $oldfh;
    }
}

##################################################
sub file_close {
##################################################
    my($self) = @_;

    undef $self->{fh};
}

##################################################
sub file_switch {
##################################################
    my($self, $new_filename) = @_;

    $self->file_close();
    $self->{filename} = $new_filename;
    $self->file_open($new_filename);
}

##################################################
sub log {
##################################################
    my($self, %params) = @_;

    my $fh = $self->{fh};

    print $fh $params{message};
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
      umask     => 0222,
    );

    $file->log(message => "Log me\n");

=head1 DESCRIPTION

This is a simple appender for writing to a file.

The C<log()> method takes a single scalar. If a newline character
should terminate the message, it has to be added explicitely.

Upon destruction of the object, the filehandle to access the
file is flushed and closed.

If you want to switch over to a different logfile, use the
C<switch_file($newfile)> method which will first close the old
file handle and then open a one to the new file specified.

=head2 OPTIONS

=over 4

=item filename

Name of the log file.

=item mode

Messages will be append to the file if C<$mode> is set to the
string C<"append">. Will clobber the file
if set to C<"clobber">. If it is C<"pipe">, the file will be understood 
as executable to pipe output to. Default mode is C<"append">.

=item autoflush

C<autoflush>, if set to a true value, triggers flushing the data
out to the file on every call to C<log()>. C<autoflush> is on by default.

=item umask

Specifies the C<umask> to use when creating the file, determining
the file's permission settings. 
If set to C<0222> (default), new
files will be created with C<rw-r--r--> permissions.
If set to C<0000>, new files will be created with C<rw-rw-rw-> permissions.

=back

Design and implementation of this module has been greatly inspired by
Dave Rolsky's C<Log::Dispatch> appender framework.

=head1 AUTHOR

Mike Schilli <log4perl@perlmeister.com>, 2003

=cut
