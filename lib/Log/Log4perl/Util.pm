package Log::Log4perl::Util;

use File::Spec;
use Module::Load::Conditional 'can_load';

##################################################
sub module_available {  # Check if a module is available, and loads it
##################################################
    my($full_name) = @_;

    return can_load(modules => { $full_name => 0 });
}

##################################################
sub tmpfile_name {  # File::Temp without the bells and whistles
##################################################

    my $name = File::Spec->catfile(File::Spec->tmpdir(), 
                              'l4p-tmpfile-' . 
                              "$$-" .
                              int(rand(9999999)));

        # Some crazy versions of File::Spec use backslashes on Win32
    $name =~ s#\\#/#g;
    return $name;
}

1;

__END__

=head1 NAME

Log::Log4perl::Util - Internal utility functions

=head1 DESCRIPTION

Only internal functions here. Don't peek.

=head1 COPYRIGHT AND LICENSE

Copyright 2002-2009 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
