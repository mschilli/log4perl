##################################################
package Log::Log4perl::Layout::SimpleLayout;
##################################################
# TODO: 'd', 't', 'x', 'X'
# as documented in
# http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html
##################################################

use 5.006;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dump qw(dump);
use Log::Log4perl::Level;

no strict qw(refs);

our $PROGRAM_START_TIME = [gettimeofday()];

use base qw(Log::Log4perl::Layout);


##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my ($appender_name, $data) = @_;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
        appender_name => $appender_name,
    };

    bless $self, $class;

    return $self;
}



##################################################
sub render {
##################################################
    my($self, $logger, $message, $category, $priority, $caller_level) = @_;

    $caller_level = 0 unless defined  $caller_level;

    return "$priority - $message";

}

1;

__END__

=head1 NAME

Log::Log4perl::Layout - Log layout

=head1 SYNOPSIS

  use Log::Log4perl::Layout;

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Mike Schilli

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
