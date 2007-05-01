use inc::Module::Install;

name           'Class-C3';
all_from       'lib/Class/C3.pm';

# Class::C3 under 5.9.5+ has no deps
if($] < 5.009_005) {
    build_requires 'Test::More'    => '0.47';

    feature 'XS Speedups',
        ($] < 5.009_005 ? ('Class::C3::XS' => '0.02') : ());

    # Would like to disable these if they answer yes above too ...
    feature '-core',
        'Algorithm::C3' => '0.06',
        'Scalar::Util'  => '1.10';
}

auto_install;
WriteAll;
