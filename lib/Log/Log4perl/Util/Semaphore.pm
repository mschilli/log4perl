#//////////////////////////////////////////
package Log::Log4perl::Util::Semaphore;
#//////////////////////////////////////////
use IPC::SysV qw(IPC_RMID IPC_CREAT IPC_EXCL SEM_UNDO IPC_NOWAIT 
                 IPC_SET IPC_STAT);
use IPC::Semaphore;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        key     => undef,
        mode    => undef,
        uid     => undef,
        gid     => undef,
        destroy => undef,
        %options,
    };

    $self->{ikey} = unpack("i", pack("A4", $self->{key}));

    bless $self, $class;
    $self->init();

    my @values = ();
    for my $param (qw(mode uid gid)) {
        push @values, $param, $self->{$param} if defined $self->{$param};
    }
    $self->semset(@values) if @values;

    return $self;
}

###########################################
sub init {
###########################################
    my($self) = @_;

    ###l4p DEBUG "Semaphore init '$self->{key}'/'$self->{ikey}'";

    $self->{id} = semget( $self->{ikey}, 
                          1, 
                          &IPC_EXCL|&IPC_CREAT|($self->{mode}||0777),
                  );
   
   if($! =~ /exists/) {
       ###l4p DEBUG "Semaphore '$self->{key}' already exists";
       $self->{id} = semget( $self->{ikey}, 1, 0 )
           or die "semget($self->{ikey}) failed: $!";
   } elsif($!) {
       die "Cannot create semaphore $self->{key}/$self->{ikey} ($!)";
   }
}

###########################################
sub semset {
###########################################
    my($self, @values) = @_;

    ###l4p "Setting values for semaphore $self->{key}/$self->{ikey}";

    my $sem = IPC::Semaphore->new($self->{ikey}, 1, 0);
    $sem->set(@values);
}

###########################################
sub semlock {
###########################################
    my($self) = @_;

    my $operation = pack("s!*", 
                          # wait until it's 0
                         0, 0, 0,
                          # increment by 1
                         0, 1, SEM_UNDO
                        );

    ###l4p DEBUG "Locking semaphore '$self->{key}'";

    semop($self->{id}, $operation) or 
        die "semop($self->{key}, $operation) failed: $! ";
}

###########################################
sub semunlock {
###########################################
    my($self) = @_;

    my $operation = pack("s!*", 
                          # decrement by 1
                         0, -1, (IPC_NOWAIT|SEM_UNDO)
                        );

    ###l4p DEBUG "Unlocking semaphore '$self->{key}'";

    semop($self->{id}, $operation) or 
        die "semop($self->{key}, $operation) failed: $! ";
}

###########################################
sub remove {
###########################################
    my($self) = @_;

    ###l4p DEBUG "Removing semaphore '$self->{key}'";

    semctl ($self->{id}, 0, &IPC_RMID, 0) or 
        die "Removing semaphore $self->{key} failed: $!";
}

###########################################
sub DESTROY {
###########################################
    my($self) = @_;

    if($self->{destroy}) {
        $self->remove();
    }
}

1;

__END__

=head1 NAME

Log::Log4perl::Util::Semaphore - Easy to use semaphores

=head1 SYNOPSIS

    use Log::Log4perl::Util::Semaphore;
    my $sem = Log::Log4perl::Util::Semaphore->new( key => "abc" );

    $sem->semlock();
      # ... critical section 
    $sem->semunlock();

    $sem->semset( uid  => (getpwnam("hugo"))[2], 
                  gid  => 102,
                  mode => 0644
                );

=head1 DESCRIPTION

Log::Log4perl::Util::Semaphore provides the synchronisation mechanism
for the Synchronized.pm appender in Log4perl, but can be used independently
of Log4perl.

=head1 LEGALESE

Copyright 2007 by Mike Schilli, all rights reserved.
This program is free software, you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

2007, Mike Schilli <cpan@perlmeister.com>
