use strict;
use warnings;
use ExtUtils::MakeMaker;

my $meta_merge = {
    META_MERGE => {
        "meta-spec" => { version => 2 },
        resources => {
            repository => {
              type => 'git',
              url => 'git@github.com:github.com/mschilli/log4perl.git',
              web => 'https://github.com/github.com/mschilli/log4perl',
            },
            MailingList => 'mailto:log4perl-devel@lists.sourceforge.net',
            bugtracker => {
                web => 'https://github.com/mschilli/log4perl/issues',
            },
        },
        prereqs => {
            runtime => {
                recommends => {
                    'Log::Dispatch' => 0,
                    'DBI' => '1.607',
                    'DBD::SQLite' => 0,
                    'DBD::CSV' => '0.33',
                    'SQL::Statement' => '1.20',
                    'Log::Dispatch::FileRotate' => '1.10',
                    'XML::DOM' => '1.29',
                },
                requires => {
                    'File::Spec'    => '0.82',
                    'File::Path'    => '2.07',
                },
            },
            test => {
                requires => {
                    'Test::More'    => '0.88', # done_testing
                },
            },
        },
    }
};

WriteMakefile(
    'NAME'		=> 'Log::Log4perl',
    'VERSION_FROM'	=> 'lib/Log/Log4perl.pm', # finds $VERSION
    ABSTRACT_FROM => 'lib/Log/Log4perl.pm', # retrieve abstract from module
    AUTHOR     => 'Mike Schilli <m@perlmeister.com>',
    MIN_PERL_VERSION => '5.006',
    'clean'             => {FILES => "*.tar.gz *.ppd pod2htm*"},
    EXE_FILES           => ["eg/l4p-tmpl"],
    LICENSE => 'perl_5',
    $ExtUtils::MakeMaker::VERSION >= 6.50 ? (%$meta_merge) : (),
    get_man3pods(), 
);

##########################################
sub get_man3pods {
##########################################
        # Only done for versions < 5.8.0
    return () if $] >= 5.008;

    print <<EOT;
##################################################
# Detected buggy MakeMaker version, creating man #
# pages manually                                 #
##################################################
EOT
    require File::Find;

    my @pms = ();

    File::Find::find(sub { 
        push @pms, $File::Find::name if /\.pm$/
    }, "lib");

    return('MAN3PODS', {
        map { my @comps = split /\//, $_;
              shift @comps;
              my $csep = join '::', @comps;
              $csep =~ s/\.pm$//;
              ($_, "\$(INST_MAN3DIR)/$csep.\$(MAN3EXT)");
            } @pms
    });
}
