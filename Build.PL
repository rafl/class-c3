use Module::Build;

use strict;

my $build = Module::Build->new(
    module_name => 'Class::C3',
    license => 'perl',
    requires => {
        'Algorithm::C3'   => 0.06,
        'Scalar::Util'    => 1.10,
    },
    recommends => {
        'Class::C3::XS'   => 0.02,
    },
    build_requires => {
        'Test::More' => '0.47',
    },
    create_makefile_pl => 'traditional',
    recursive_test_files => 1,
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', 'Makefile.PL',
    ],
);

$build->create_build_script;

