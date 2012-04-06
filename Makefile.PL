use warnings;
use strict;

use 5.006002;
use inc::Module::Install 1.06;

perl_version   '5.006002';
name           'Class-C3';
all_from       'lib/Class/C3.pm';

test_requires 'Test::More' => '0.47';

# needed by the PP version only, have them installed
# regardless of XS availability or perl version
# (for fatpacking and whatnot)
requires 'Algorithm::C3' => '0.07';
requires 'Scalar::Util'  => '0';

# XS not interesting after mro is cored
requires 'Class::C3::XS'  => '0.13'
  if $] < 5.009_005 and can_xs();

test_requires 'Devel::Hide' => 0
  if is_smoker();

if($Module::Install::AUTHOR) {
  # compiler detection, goes into META
  configure_requires 'ExtUtils::MakeMaker' => '6.52';
  configure_requires 'ExtUtils::CBuilder'  => '0.27';

  # Rebuild README for maintainers
  system("pod2text lib/Class/C3.pm >README");
}

WriteAll;

if ($Module::Install::AUTHOR) {
  @{Meta->{values}{requires}} = grep
    { $_->[0] !~ /^ (?: Class::C3::XS | Devel::Hide ) $/x }
    @{Meta->{values}{requires}}
  ;
  print "Regenerating META with XS/test requires excluded\n";
  Meta->write;
}

sub is_smoker {
  return ( $ENV{AUTOMATED_TESTING} && ! $ENV{PERL5_CPANM_IS_RUNNING} && ! $ENV{RELEASE_TESTING} )
}
