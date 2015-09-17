##################################################
package Log::Log4perl::Layout::FallbackLayout;
##################################################

use Carp;
use Log::Log4perl::Config ();

    use Data::Dump qw/ pp /;

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $options =  ref $_[0] eq "HASH" ? shift : {};
    #warn pp( $options ). "\n\n";

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    if( defined $options->{ chain } ) {
        $self->{ _chainLayout } =
            Log::Log4perl::Config::create_layout( $options->{ chain } );

        delete $options->{ chain };
    }

    bless $self, $class;

    return $self;
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    if( ref $message eq "ARRAY" ) {
        for my $i (0..$#{$message}) {
            if( !defined $message->[ $i ] ) {
                local $Carp::CarpLevel =
                $Carp::CarpLevel + $Log::Log4perl::caller_depth + 1;
                carp "Warning: Log message argument #" .
                     ($i+1) . " undefined";
            }
        }

        $message =  join( $Log::Log4perl::JOIN_MSG_ARRAY_CHAR, @{ $message } );
    }

    if( defined $self->{ _chainLayout } ) {
        $message =  $self->{ _chainLayout }->render( $message );
    }

    return $message;
}

1;

__END__

=encoding utf8

=head1 NAME

Log::Log4perl::Layout::FallbackLayout - workaround for warp_message

=head1 SYNOPSIS

    log4perl.appender.A1.layout=FallbackLayout
    log4perl.appender.A1.layout.chain=PatternLayout
    log4perl.appender.A1.layout.chain.ConversionPattern=%m%n
    log4perl.appender.A1.warp_message = sub { $#_ = 2 if @_ > 3; \
                                           return @_; }

=head1 DESCRIPTION

This layout returns the logging message as single string instead of
an array reference.

Usefull with the standard appenders in the Log::Dispatch hierarchy
when you use 'warp_message' option for the appender

=head1 LICENSE

Copyright 2015 by Eugen Koknov E<lt>kes-kes@yandex.ruE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Please contribute patches to the project on Github:

    http://github.com/mschilli/log4perl

Send bug reports or requests for enhancements to the authors via our

MAILING LIST (questions, bug reports, suggestions/patches):
log4perl-devel@lists.sourceforge.net

Authors (please contact them via the list above, not directly):
Eugen Konkov <kes-kes@yandex.ru>,
