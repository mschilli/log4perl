use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Log::Log4perl',
    'VERSION_FROM'	=> 'lib/Log/Log4perl.pm', # finds $VERSION
    'PREREQ_PM'		=> { Log::Dispatch => 2.00,
                             Time::HiRes   => 1.20,
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
);
