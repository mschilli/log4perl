##################################################
package Log::Log4perl::Appender::File;
##################################################

our @ISA = qw(Log::Log4perl::Appender);

use warnings;
use strict;
use Log::Log4perl::Config::Watch;

##################################################
sub new {
##################################################
    my($class, @options) = @_;

    my $self = {
        name      => "unknown name",
        umask     => undef,
        autoflush => 1,
        mode      => "append",
        binmode   => undef,
        utf8      => undef,
        recreate  => 0,
        recreate_check_interval => 30,
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
        die "Can't open $self->{filename} ($!)";

    if($self->{recreate}) {
        $self->{watcher} = Log::Log4perl::Config::Watch->new(
            file           => $self->{filename},
            check_interval => $self->{recreate_check_interval},
        );
    }

    umask($old_umask) if defined $self->{umask};

    $self->{fh} = $fh;

    if ($self->{autoflush}) {
        my $oldfh = select $self->{fh}; 
        $| = 1; 
        select $oldfh;
    }

    if (defined $self->{binmode}) {
        binmode $self->{fh}, $self->{binmode};
    }

    if (defined $self->{utf8}) {
        binmode $self->{fh}, ":utf8";
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
    $self->file_open();
}

##################################################
sub log {
##################################################
    my($self, %params) = @_;

    if($self->{recreate}) {
        if($self->{watcher}->file_has_moved()) {
            $self->file_switch($self->{filename});
        }
    }

    my $fh = $self->{fh};

    print $fh $params{message} or
        die "Cannot write to '$self->{filename}': $!";
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
C<file_switch($newfile)> method which will first close the old
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

=item utf8

If you're printing out Unicode strings, the output filehandle needs
to be set into C<:utf8> mode:

    my $app = Log::Log4perl::Appender::File->new(
      filename  => 'file.log',
      mode      => 'append',
      utf8      => 1,
    );

=item binmode

To manipulate the output filehandle via C<binmode()>, use the
binmode parameter:

    my $app = Log::Log4perl::Appender::File->new(
      filename  => 'file.log',
      mode      => 'append',
      binmode   => ":utf8",
    );

A setting of ":utf8" for C<binmode> is equivalent to specifying
the C<utf8> option (see above).

=item recreate

Normally, if a file appender logs to a file and the file gets moved to
a different location (e.g. via C<mv>), the appender's open file handle
will automatically follow the file to the new location.

This may be undesirable. When using an external logfile rotator, 
for example, the appender should create a new file under the old name
and start logging into it. If the C<recreate> option is set to a true value, 
C<Log::Log4perl::Appender::File> will do exactly that. It defaults to 
false. Check the C<recreate_check_interval> option for performance 
optimizations with this feature.

=item recreate_check_interval

In C<recreate> mode, the appender has to continuously check if the
file it is logging to is still in the same location. This check is
fairly expensive, since it has to call C<stat> on the file name and
figure out if its inode has changed. Doing this with every call
to C<log> can be prohibitively expensive. Setting it to a positive
integer value N will only check the file every N seconds. It defaults to 30.

This obviously means that the appender will continue writing to 
a moved file until the next check occurs, in the worst case
this will happen C<recreate_check_interval> seconds after the file
has been moved or deleted. If this is undesirable,
setting C<recreate_check_interval> to 0 will have the appender
appender check the file with I<every> call to C<log()>.

=back

Design and implementation of this module has been greatly inspired by
Dave Rolsky's C<Log::Dispatch> appender framework.

=head1 AUTHOR

Mike Schilli <log4perl@perlmeister.com>, 2003, 2005

=cut
