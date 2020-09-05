use ExtUtils::MakeMaker;

# Check for Time::HiRes;
eval { require Time::HiRes; };
if($@) {
    print "Warning: Time::HiRes not installed, but that's ok, " .
          "%r will use full seconds\n";
}

my $meta_merge = {
    META_MERGE => {
        "meta-spec" => { version => 2 },
        resources => {
            repository  => 'http://github.com/mschilli/log4perl',
            MailingList => 'mailto:log4perl-devel@lists.sourceforge.net',
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
            },
        },
    }
};

WriteMakefile(
    'NAME'		=> 'Log::Log4perl',
    'VERSION_FROM'	=> 'lib/Log/Log4perl.pm', # finds $VERSION
    'PREREQ_PM'		=> { Test::More    => 0.45,
                             File::Spec    => 0.82,
                             File::Path    => 2.06_06,
                           }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM => 'lib/Log/Log4perl.pm', # retrieve abstract from module
    AUTHOR     => 'Mike Schilli <m@perlmeister.com>',
    MIN_PERL_VERSION => '5.006',
    'clean'             => {FILES => "*.tar.gz *.ppd pod2htm*"},
    EXE_FILES           => ["eg/l4p-tmpl"],
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
