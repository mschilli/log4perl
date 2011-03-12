package Log::Log4perl::JavaMap::SMTPAppender;

use Carp;
use strict;
use Log::Dispatch::Email::MailSender;

sub new {
    my ($class, $appender_name, $data) = @_;
    my $stderr;

	my %args;

    $args{subject} = $data->{Subject}{value} || $data->{subject}{value};

    $args{to} = $data->{To}{value} ||
	      $data->{to}{value} ||
		  die "'To' not supplied for appender '$appender_name', required for a '$data->{value}'\n";

    $args{from} = $data->{From}{value} || $data->{from}{value};

    if (defined($data->{sendOnClose}{value})){
      if (lc $data->{sendOnClose}{value} eq 'true' || $data->{sendOnClose}{value} == 1){
            $args{buffered} = 1;
        }elsif (lc $data->{sendOnClose}{value} eq 'false' || $data->{sendOnClose}{value} == 0) {
            $args{buffered} = 0;
        }else{
            die "'$data->{sendOnClose}' is not a legal value for sendOnClose for appender '$appender_name', '$data->{value}'\n";
        }
    }else{
        $args{buffered} = 1;
    }

    $args{smtp} = $data->{SMTPHost}{value};

    %args = map { $_ => $args{$_} } grep { defined $args{$_} } ('subject', 'to', 'from', 'smtp', 'buffered');

    return Log::Log4perl::Appender->new("Log::Dispatch::Email::MailSender",
        name      => $appender_name,
        %args,
    );
}

1;

=head1 NAME

Log::Log4perl::JavaMap::SMTPAppender - wraps Log::Dispatch::Email::MailSender

=head1 SYNOPSIS


=head1 DESCRIPTION

This maps log4j's SMTPAppender to Log::Dispatch::Email::MailSender
by Pavel Denisov, <pavel.a.denisov@gmail.com>.

Possible config properties for log4j SMTPAppender are 

	Subject
    To
	From
	SMTPHost
    sendOnClose

=head1 SEE ALSO

Log::Log4perl::Javamap

=head1 COPYRIGHT AND LICENSE

Copyright 2002-2011 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
