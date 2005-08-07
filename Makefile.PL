use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Class::C3',
    'VERSION_FROM'	=> 'lib/Class/C3.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'Test::More'      => 0.47,
        'Test::Exception' => 0.15,
        'Scalar::Util'    => 1.10	
		}
);
