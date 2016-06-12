package Log::Log4perl::Global;

#version required for XML::DOM, to enable XML Config parsing
#and XML Config unit tests
our $DOM_VERSION_REQUIRED = '1.29';

#arrays in a log message will be joined using this character,
#see Log::Log4perl::Appender::DBI
our $JOIN_MSG_ARRAY_CHAR = '';

our $CHATTY_DESTROY_METHODS   = 0;
our $GMTIME                   = 0;
our $INITIALIZED              = 0;
our $NO_STRICT                = 0;
our $one_message_per_appender = 0;
our $SIGNAL_CAUGHT;

1;

__END__

=encoding utf8

=head1 NAME

Log::Log4perl::Global - Internal utility module to consolidate globals

=head1 DESCRIPTION

Used to consolidate globals found interspersed through the code in order
to encapsulate and hopefully eliminate them!

=head1 LICENSE

Copyright 2002-2013 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
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


