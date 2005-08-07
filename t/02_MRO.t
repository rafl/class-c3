#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 15;

BEGIN {
    use_ok('Class::C3');
}

=pod

                          6
                         ---
Level 3                 | O |                  (more general)
                      /  ---  \
                     /    |    \                      |
                    /     |     \                     |
                   /      |      \                    |
                  ---    ---    ---                   |
Level 2        3 | D | 4| E |  | F | 5                |
                  ---    ---    ---                   |
                   \  \ _ /       |                   |
                    \    / \ _    |                   |
                     \  /      \  |                   |
                      ---      ---                    |
Level 1            1 | B |    | C | 2                 |
                      ---      ---                    |
                        \      /                      |
                         \    /                      \ /
                           ---
Level 0                 0 | A |                (more specialized)
                           ---

=cut

{
    package Test::O;
    use Class::C3; 
    
    package Test::F;   
    use Class::C3;  
    use base 'Test::O';        
    
    package Test::E;
    use base 'Test::O';    
    use Class::C3;     
    
    sub C_or_E { 'Test::E' }

    package Test::D;
    use Class::C3; 
    use base 'Test::O';     
    
    sub C_or_D { 'Test::D' }       
      
    package Test::C;
    use base ('Test::D', 'Test::F');
    use Class::C3; 
    
    sub C_or_D { 'Test::C' }
    sub C_or_E { 'Test::C' }    
        
    package Test::B;    
    use Class::C3; 
    use base ('Test::D', 'Test::E');    
        
    package Test::A;    
    use base ('Test::B', 'Test::C');
    use Class::C3;    
}

is_deeply(
    [ Class::C3::calculateMRO('Test::F') ],
    [ qw(Test::F Test::O) ],
    '... got the right MRO for Test::F');

is_deeply(
    [ Class::C3::calculateMRO('Test::E') ],
    [ qw(Test::E Test::O) ],
    '... got the right MRO for Test::E');    

is_deeply(
    [ Class::C3::calculateMRO('Test::D') ],
    [ qw(Test::D Test::O) ],
    '... got the right MRO for Test::D');       

is_deeply(
    [ Class::C3::calculateMRO('Test::C') ],
    [ qw(Test::C Test::D Test::F Test::O) ],
    '... got the right MRO for Test::C'); 

is_deeply(
    [ Class::C3::calculateMRO('Test::B') ],
    [ qw(Test::B Test::D Test::E Test::O) ],
    '... got the right MRO for Test::B');     

is_deeply(
    [ Class::C3::calculateMRO('Test::A') ],
    [ qw(Test::A Test::B Test::C Test::D Test::E Test::F Test::O) ],
    '... got the right MRO for Test::A');  
    
is(Test::A->C_or_D, 'Test::C', '... got the expected method output');
is(Test::A->can('C_or_D')->(), 'Test::C', '... can got the expected method output');

is(Test::B->C_or_D, 'Test::D', '... got the expected method output');
is(Test::B->can('C_or_D')->(), 'Test::D', '... can got the expected method output');

is(Test::A->C_or_E, 'Test::C', '... got the expected method output');
is(Test::A->can('C_or_E')->(), 'Test::C', '... can got the expected method output');

is(Test::B->C_or_E, 'Test::E', '... got the expected method output');
is(Test::B->can('C_or_E')->(), 'Test::E', '... can got the expected method output');

    