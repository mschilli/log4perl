use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

    # That's the minimum.
use 5.00503;

    # If we're not 5.6.0, there's some corrections we need to make: Use
    # 'use vars' instead of 'our' variables, get rid of 'use warnings'
    # and other stuff. The eg/5005it.pl script takes care of it.
if($] < 5.006) {
    require "eg/5005it.pl";

    print <<EOT;
########################################################
# Hm, you're still using perl 5.005. Although I don't  #
# condone that, I'll let it slip this time:            #
# Changing distribution to be backwards compatible ... #
EOT
    mk5005("t", "lib");
    print <<EOT;
# Done. But do me a favour and upgrade soon.           # 
########################################################
EOT
}

# Check for Time::HiRes;
eval { require Time::HiRes; };
if($@) {
    print "Warning: Time::HiRes not installed, but that's ok, " .
          "%r will use full seconds\n";
}

WriteMakefile(
    'NAME'		=> 'Log::Log4perl',
    'VERSION_FROM'	=> 'lib/Log/Log4perl.pm', # finds $VERSION
    'PREREQ_PM'		=> { Log::Dispatch => 2.00,
	                     Test::Simple  => 0.43,
                             Test::More    => 0.45,
                             File::Spec    => 0.82,
                           }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Log/Log4perl.pm', # retrieve abstract from module
       AUTHOR     => 'Mike <m@perlmeister.com>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> '', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
    'clean'             => {FILES => "*.tar.gz *.ppd pod2htm*"},
);
