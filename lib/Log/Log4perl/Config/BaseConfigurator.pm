package Log::Log4perl::Config::BaseConfigurator;

use warnings;
use strict;

################################################
sub new {
################################################
    my($class, %options) = @_;

    my $self = { 
        %options,
               };

    $self->file($self->{file}) if exists $self->{file};

    bless $self, $class;
}

################################################
sub text {
################################################
    my($self, $text) = @_;

        # $text is an array of scalars (lines)
    if(defined $text) {
        if(ref $text eq "ARRAY") {
            $self->{text} = $text;
        } else {
            $self->{text} = [split "\n", $text];
        }
    }

    return $self->{text};
}

################################################
sub file {
################################################
    my($self, $filename) = @_;

    open FILE, "<$filename" or die "Cannot open $filename ($!)";
    $self->{text} = [<FILE>];
    close FILE;
}

1;

__END__

=head1 NAME

Log::Log4perl::Config::BaseConfigurator - Configurator Base Class

=head1 SYNOPSIS

This is a virtual base class, all configurators should be derived from it.

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item C<< new >>

Constructor, typically called like 

    my $config_parser = SomeConfigParser->new(
        file => $file,
    );

    my $data = $config_parser->parse();

Accepts the following parameters:

=over 4

=item C<< file >>

Specifies a file which the C<parse()> method later parses.

=item C<< text >>

Specifies a reference to an array of scalars, representing configuration
records (typically lines of a file). Also accepts a simple scalar, which it 
splits at its newlines and transforms it into an array:

    my $config_parser = MyYAMLParser->new(
        text => ['foo: bar',
                 'baz: bam',
                ],
    );
    my $data = $config_parser->parse();

C<$data> needs to point to the config data structure, which
is a a hash of hashes:

    $data->{log4perl}->{category}->{Bar}->{Twix} = "WARN, Logfile"
    $data->{log4perl}->{appender}->{Logfile} = 
        "Log::Log4perl::Appender::File";
    ...

=back

=head1 SEE ALSO

Log::Log4perl::Config::PropertyConfigurator

Log::Log4perl::Config::DOMConfigurator

Log::Log4perl::Config::LDAPConfigurator (tbd!)

=head1 AUTHOR

Kevin Goess, <cpan@goess.org> Jan-2003

=cut
