
package Class::C3;

use strict;
use warnings;

our $VERSION = '0.01';

use Scalar::Util 'blessed';

my %MRO;

sub import {
    my $class = caller();
    return if $class eq 'main';
    $MRO{$class} = undef;
}

INIT {
    no strict 'refs';    
    foreach my $class (keys %MRO) {
        my @MRO = calculateMRO($class);
        $MRO{$class} = { MRO => \@MRO };
        my %methods;
        foreach my $local (@MRO[1 .. $#MRO]) {
            foreach my $method (grep { defined &{"${local}::$_"} } keys %{"${local}::"}) {
                next unless !defined *{"${class}::$method"}{CODE};
                if (!exists $methods{$method}) {
                    $methods{$method} = {
                        orig => "${local}::$method",
                        code => \&{"${local}::$method"}
                    };
                }
            }
        }    
        $MRO{$class}->{methods} = \%methods;
    }
    #use Data::Dumper; warn Dumper \%MRO; 
    foreach my $class (keys %MRO) {
        #warn "installing methods (" . (join ", " => keys %{$MRO{$class}->{methods}}) . ") for $class";
        foreach my $method (keys %{$MRO{$class}->{methods}}) {
            #warn "Installing ${class}::$method using " . $MRO{$class}->{methods}->{$method}->{orig};
            *{"${class}::$method"} = $MRO{$class}->{methods}->{$method}->{code};
        }
    }   
}

sub _merge {                
    my (@seqs) = @_;
    my @res; 
    while (1) {
        # remove all empty seqences
        my @nonemptyseqs = (map { (@{$_} ? $_ : ()) } @seqs);
        # return the list if we have no more no-empty sequences
        return @res if not @nonemptyseqs; 
        my $cand; # a canidate ..
        foreach my $seq (@nonemptyseqs) {
            $cand = $seq->[0]; # get the head of the list
            my $nothead;            
            foreach my $sub_seq (@nonemptyseqs) {
                # XXX - this is instead of the python "in"
                my %in_tail = (map { $_ => 1 } @{$sub_seq}[ 1 .. $#{$sub_seq} ]);
                # NOTE:
                # jump out as soon as we find one matching
                # there is no reason not too. However, if 
                # we find one, then just remove the '&& last'
                $nothead++ && last if exists $in_tail{$cand};      
            }
            last unless $nothead; # leave the loop with our canidate ...
            $cand = undef;        # otherwise, reject it ...
        }
        die "Inconsistent hierarchy" if not $cand;
        push @res => $cand;
        # now loop through our non-empties and pop 
        # off the head if it matches our canidate
        foreach my $seq (@nonemptyseqs) {
            shift @{$seq} if $seq->[0] eq $cand;
        }
    }
}

sub calculateMRO {
    my ($class) = @_;
    no strict 'refs';
    return _merge(
        [ $class ],                                        # the class we are linearizing
        (map { [ calculateMRO($_) ] } @{"${class}::ISA"}), # the MRO of all the superclasses
        [ @{"${class}::ISA"} ]                             # a list of all the superclasses    
    );
}

1;

__END__

=pod

=head1 NAME

Class::C3 - A pragma to use the C3 method resolution order algortihm

=head1 SYNOPSIS

    package A;
    use Class::C3;     
    sub hello { 'A::hello' }

    package B;
    use base 'A';
    use Class::C3;     

    package C;
    use base 'A';
    use Class::C3;     

    sub hello { 'C::hello' }

    package D;
    use base ('B', 'C');
    use Class::C3;    

    # Classic Diamond MI pattern
    #    [ A ]
    #   /     \
    # [ B ]  [ C ]
    #   \     /
    #    [ D ]

    package main;

    print join ', ' => Class::C3::calculateMRO('Diamond_D') # prints D, B, C, A

    print D->hello() # prints 'C::hello' instead of the standard p5 'A::hello'
    
    D->can('hello')->();          # can() also works correctly
    UNIVERSAL::can('D', 'hello'); # as does UNIVERSAL::can()

=head1 DESCRIPTION

This is currently an experimental pragma to change Perl 5's standard method resolution order 
from depth-first left-to-right (a.k.a - pre-order) to the more sophisticated C3 method resolution
order. 

=head2 What is C3?

C3 is the name of an algorithm which aims to provide a sane method resolution order under multiple
inheritence. It was first introduced in the langauge Dylan (see links in the L<SEE ALSO> section),
and then later adopted as the prefered MRO (Method Resolution Order) for the new-style classes in 
Python 2.3. Most recently it has been adopted as the 'canonical' MRO for Perl 6 classes, and the 
default MRO for Parrot objects as well.

=head2 How does C3 work.

C3 works by always preserving local precendence ordering. This essentially means that no class will 
appear before any of it's subclasses. Take the classic diamond inheritence pattern for instance:

    [ A ]
   /     \
 [ B ]  [ C ]
   \     /
    [ D ]

The standard Perl 5 MRO would be (D, B, A, C). The result being that B<A> appears before B<C>, even 
though B<C> is the subclass of B<A>. The C3 MRO algorithm however, produces the following MRO 
(D, B, C, A), which does not have this same issue.

This example is fairly trival, for more complex examples and a deeper explaination, see the links in
the L<SEE ALSO> section.

=head2 How does this module work?

This module uses a technique similar to Perl 5's method caching. During the INIT phase, this module 
calculates the MRO of all the classes which called C<use Class::C3>. It then gathers information from 
the symbol tables of each of those classes, and builds a set of method aliases for the correct 
dispatch ordering. Once all these C3-based method tables are created, it then adds the method aliases
into the local classes symbol table. 

The end result is actually classes with pre-cached method dispatch. However, this caching does not
do well if you start changing your C<@ISA> or messing with class symbol tables, so you should consider
your classes to be effectively closed. See the L<CAVEATS> section for more details.

=head1 FUNCTIONS

=over 4

=item B<calculateMRO ($class)>

Given a C<$class> this will return an array of class names in the proper C3 method resolution order.

=back

=head1 CAVEATS

Let me first say, this is an experimental module, and so it should not be used for anything other 
then other experimentation for the time being. 

That said, it is the authors intention to make this into a completely usable and production stable 
module if possible. Time will tell.

And now, onto the caveats.

=over 4

=item Use of C<SUPER::>.

The idea of C<SUPER::> under multiple inheritence is ambigious, and generally not recomended anyway.
However, it's use in conjuntion with this module is very much not recommended, and in fact very 
discouraged. In the future I plan to support a C<NEXT::> style interface to be used to move to the 
next most appropriate method in the MRO.

=item Changing C<@ISA>.

It is the author's opinion that changing C<@ISA> at runtime is pure insanity anyway. However, people
do it, so I must caveat. Any changes to the C<@ISA> will not be reflected in the MRO calculated by this
module, and therefor probably won't even show up. I am considering some kind of C<recalculateMRO> function
which can be used to recalculate the MRO on demand at runtime, but that is still off in the future.

=item Adding/deleting methods from class symbol tables.

This module calculates the MRO for each requested class during the INIT phase by interogatting the symbol
tables of said classes. So any symbol table manipulation which takes place after our INIT phase is run will
not be reflected in the calculated MRO.

=item Not for use with mod_perl

Since this module utilizes the INIT phase, it cannot be easily used with mod_perl. If this module works out
and proves useful in the I<real world>, I will most likely be supporting mod_perl in some way.

=back

=head1 TODO

=over 4

=item More tests

You can never have enough tests :)

I need to convert the other MRO and class-precendence-list related tests from the Perl6-MetaModel (see link
in L<SEE ALSO>). In addition, I need to add some method checks to these tests as well.

=item call-next-method / NEXT:: / next METHOD

I am contemplating some kind of psudeo-package which can dispatch to the next most relevant method in the 
MRO. This should not be too hard to implement when the time comes.

=item recalculateMRO

This being Perl, it would be remiss of me to force people to close thier classes at runtime. So I need to 
develop a means for recalculating the MRO for a given class. 

=back

=head1 SEE ALSO

=head2 The original Dylan paper

=over 4

=item L<http://www.webcom.com/haahr/dylan/linearization-oopsla96.html>

=back

=head2 The prototype Perl 6 Object Model uses C3

=over 4

=item L<http://svn.openfoundry.org/pugs/perl5/Perl6-MetaModel/>

=back

=head2 Parrot now uses C3

=over 4

=item L<http://aspn.activestate.com/ASPN/Mail/Message/perl6-internals/2746631>

=item L<http://use.perl.org/~autrijus/journal/25768>

=back

=head2 Python 2.3 MRO related links

=over 4

=item L<http://www.python.org/2.3/mro.html>

=item L<http://www.python.org/2.2.2/descrintro.html#mro>

=back

=head2 C3 for TinyCLOS

=over 4

=item L<http://www.call-with-current-continuation.org/eggs/c3.html>

=back 

=head1 AUTHOR

stevan little, E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut