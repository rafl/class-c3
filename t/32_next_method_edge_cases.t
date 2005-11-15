#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

BEGIN {   
    use_ok('Class::C3');
}

use Sub::Name;

{

    {
        package Foo;
        use strict;
        use warnings;
        use Class::C3;
        sub new { bless {}, $_[0] }
        sub bar { 'Foo::bar' }
    }

    # call the submethod in the direct instance

    my $foo = Foo->new();
    isa_ok($foo, 'Foo');

    can_ok($foo, 'bar');
    is($foo->bar(), 'Foo::bar', '... got the right return value');    

    # fail calling it from a subclass

    {
        package Bar;
        use strict;
        use warnings;
        use Class::C3;
        our @ISA = ('Foo');
    }
    
    my $m = sub { (shift)->next::method() };
    subname('Bar::bar', $m);
    {
        no strict 'refs';
        *{'Bar::bar'} = $m;
    }

    my $bar = Bar->new();
    isa_ok($bar, 'Bar');
    isa_ok($bar, 'Foo');

    can_ok($bar, 'bar');
    my $value = eval { $bar->bar() };
    ok(!$@, '... calling bar() succedded') || diag $@;
    is($value, 'Foo::bar', '... got the right return value too');
}