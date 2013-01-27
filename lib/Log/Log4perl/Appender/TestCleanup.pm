##################################################
package Log::Log4perl::Appender::TestCleanup;
##################################################

use warnings;
use strict;
use Data::Dumper;
use Carp qw( cluck );
our @ISA = qw(Log::Log4perl::Appender);

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = { 
        %options
    };
    bless $self, $class;

    if( $options{ composite } ) {
        $self->composite( 1 );
    }

    return $self;
}

##################################################
sub log {
##################################################
    # ignore
}

###########################################
sub reg_cb {
###########################################
    my( $self, $cb ) = @_;

    $self->{ cb } = $cb;
}

###########################################
sub DESTROY {
###########################################
    my( $self ) = @_;

    # warn Dumper( $self );

    if( exists $self->{ cb } ) {
        $self->{ cb }->();
    } else {
        cluck "DESTROY called in ", __PACKAGE__;
    }
}

1;

__END__

=head1 NAME

Log::Log4perl::Appender::TestCleanup - Testing Log4perl appender cleanup

=head1 SYNOPSIS

    use Log::Log4perl::Appender::TestCleanup;

    my $app = Log::Log4perl::Appender::TestCleanup->new();
    $app->reg_cb( sub { 
        warn "I'm being cleaned up!";
    }

=head1 DESCRIPTION

This is an appender for internal Log4perl testing. It registers a callback
that gets triggered as soon as the appender gets garbage collected.

=head1 LICENSE

Copyright 2002-2012 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 AUTHOR

Please contribute patches to the project on Github:

    http://github.com/mschilli/log4perl

Send bug reports or requests for enhancements to the authors via our

MAILING LIST (questions, bug reports, suggestions/patches): 
log4perl-devel@lists.sourceforge.net

Authors (please contact them via the list above, not directly):
Mike Schilli <m@perlmeister.com>,
Kevin Goess <cpan@goess.org>

Contributors (in alphabetical order):
Ateeq Altaf, Cory Bennett, Jens Berthold, Jeremy Bopp, Hutton
Davidson, Chris R. Donnelly, Matisse Enzer, Hugh Esco, Anthony
Foiani, James FitzGibbon, Carl Franks, Dennis Gregorovic, Andy
Grundman, Paul Harrington, David Hull, Robert Jacobson, Jason Kohles, 
Jeff Macdonald, Markus Peter, Brett Rann, Peter Rabbitson, Erik
Selberg, Aaron Straup Cope, Lars Thegler, David Viner, Mac Yang.

