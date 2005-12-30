use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'Class::C3',
    'VERSION_FROM'	=> 'lib/Class/C3.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'Test::More'      => 0.47,
        'Test::Exception' => 0.15,
        'Scalar::Util'    => 1.10,
        'Sub::Name'       => 0,
        'NEXT'            => 0,     # for tests only
		}
);
