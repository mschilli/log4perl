package Log::Log4perl::Filter::MDC;
use strict;
use warnings;

use Log::Log4perl::Util qw( params_check );

use base "Log::Log4perl::Filter";

sub new {
    my ( $class, %options ) = @_;

    my $self = {%options};

    params_check( $self, [qw( KeyToMatch RegexToMatch )] );

    $self->{RegexToMatch} = qr/$self->{RegexToMatch}/;

    bless $self, $class;

    return $self;
}

sub ok {
    my ( $self, %p ) = @_;

    my $context = Log::Log4perl::MDC->get_context;

    my $value = $context->{ $self->{KeyToMatch} };
    return 1
        if defined $value && $value =~ $self->{RegexToMatch};

    return 0;
}

1;

__END__

=encoding utf8

=head1 NAME

Log::Log4perl::Filter::MDC - Filter to match on values of a MDC key

=head1 SYNOPSIS

    log4perl.filter.Match1               = Log::Log4perl::Filter::MDC
    log4perl.filter.Match1.KeyToMatch    = foo
    log4perl.filter.Match1.RegexToMatch  = bar

=head1 DESCRIPTION

This Log4perl filter checks if a predefined MDC key, as set in C<KeyToMatch>,
of the currently submitted message matches a predefined regex, as set in
C<RegexToMatch>.

=head1 SEE ALSO

L<Log::Log4perl::Filter>,
L<Log::Log4perl::Filter::Boolean>,
L<Log::Log4perl::Filter::LevelMatch>,
L<Log::Log4perl::Filter::LevelRange>,
L<Log::Log4perl::Filter::MDC>,
L<Log::Log4perl::Filter::StringMatch>

=head1 LICENSE

Copyright 2002-2026 by Mike Schilli E<lt>m@perlmeister.comE<gt>
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
