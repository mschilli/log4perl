package Log::Log4perl::Resurrector;
use warnings;
use strict;

use File::Temp qw(tempfile);

use constant INTERNAL_DEBUG => 0;

###########################################
sub import {
###########################################
    resurrector_init();
}

##################################################
sub resurrector_fh {
##################################################
    my($file) = @_;

    local($/) = undef;
    open FILE, "<$file" or die "Cannot open $file";
    my $text = <FILE>;
    close FILE;

    print "Read ", length($text), " bytes from $file\n" if INTERNAL_DEBUG;

    my($tmp_fh, $tmpfile) = tempfile( UNLINK => 1 );
    print "Opened tmpfile $tmpfile\n" if INTERNAL_DEBUG;

    $text =~ s/^\s*###l4p//m;

    print $tmp_fh $text;
    seek $tmp_fh, 0, 0;

    return $tmp_fh;
}

###########################################
sub resurrector_loader {
###########################################
    my ($code, $module) = @_;

      # Skip Log4perl appenders
    if($module =~ m#^Log/Log4perl/Appender#) {
        return undef;
    }

    print "Resurrecting module $module\n" if INTERNAL_DEBUG;

    my $fh = resurrector_fh($module);

    $INC{$module} = 1;
    return $fh;
}

###########################################
sub resurrector_init {
###########################################
    unshift @INC, \&resurrector_loader;
}

1;

__END__

=head1 NAME

Log::Log4perl::Resurrector - Dark Magic to resurrect hidden L4p statements

=head1 DESCRIPTION

Loading C<use Log::Log4perl::Resurrector> causes subsequently loaded
modules to have their hidden

    ###l4p DEBUG(...)
    ###l4p INFO(...)
    ...

statements uncommented and therefore 'resurrected', i.e. activated.

This allows for a module C<Foobar.pm> to be written with Log4perl
statements commented out and running at full speed in normal mode.
When loaded via

    use Foobar;

all hidden Log4perl statements will be ignored.

However, if a script loads the module C<Foobar> I<after> loading 
C<Log::Log4perl::Resurrector>, as in

    use Log::Log4perl::Resurrector;
    use Foobar;

then C<Log::Log4perl::Resurrector> will have put a source filter in place
that will extract all hidden Log4perl statements in C<Foobar> before 
C<Foobar> actually gets loaded. 

Therefore, C<Foobar> will then behave as if the

    ###l4p DEBUG(...)
    ###l4p INFO(...)
    ...

statements were actually written like

    DEBUG(...)
    INFO(...)
    ...

and the module C<Foobar> will indeed be Log4perl-enabled. Whether any
activated Log4perl statement will actually trigger log
messages, is up to the Log4perl configuration, of course.

There's a startup cost to using C<Log::Log4perl::Resurrector> (all
subsequently loaded modules are examined) but once the compilation
phase has finished, the perl program will run at full speed.

The techniques used in this module have been stolen from the
C<Acme::Incorporated> CPAN module, written by I<chromatic>. Long
live CPAN!

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2002-2007 by Mike Schilli E<lt>m@perlmeister.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
