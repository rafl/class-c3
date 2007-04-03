
package Class::C3::PurePerl;

our $VERSION = '0.15';

=pod

=head1 NAME

Class::C3::PurePerl - The default pure-Perl implementation of Class::C3

=head1 DESCRIPTION

This is the plain pure-Perl implementation of Class::C3.  The main Class::C3 package will
first attempt to load L<Class::C3::XS>, and then failing that, will fall back to this.  Do
not use this package directly, use L<Class::C3> instead.

=head1 AUTHOR

Stevan Little, E<lt>stevan@iinteractive.comE<gt>

Brandon L. Black, E<lt>blblack@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005, 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

package # hide me from PAUSE
    Class::C3;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION = '0.15';
our $C3_IN_CORE;

BEGIN {
    eval "require mro";
    if($@) {
        eval "require Algorithm::C3";
        die "Could not load 'mro' or 'Algorithm::C3'!" if $@;
    }
    else {
        $C3_IN_CORE = 1;
    }
}

# this is our global stash of both 
# MRO's and method dispatch tables
# the structure basically looks like
# this:
#
#   $MRO{$class} = {
#      MRO => [ <class precendence list> ],
#      methods => {
#          orig => <original location of method>,
#          code => \&<ref to original method>
#      },
#      has_overload_fallback => (1 | 0)
#   }
#
our %MRO;

# use these for debugging ...
sub _dump_MRO_table { %MRO }
our $TURN_OFF_C3 = 0;

# state tracking for initialize()/uninitialize()
our $_initialized = 0;

sub import {
    my $class = caller();
    # skip if the caller is main::
    # since that is clearly not relevant
    return if $class eq 'main';

    return if $TURN_OFF_C3;
    mro::set_mro_c3($class) if $C3_IN_CORE;

    # make a note to calculate $class 
    # during INIT phase
    $MRO{$class} = undef unless exists $MRO{$class};
}

## initializers

sub initialize {
    %next::METHOD_CACHE = ();
    # why bother if we don't have anything ...
    return unless keys %MRO;
    if($C3_IN_CORE) {
        mro::set_mro_c3($_) for keys %MRO;
    }
    else {
        if($_initialized) {
            uninitialize();
            $MRO{$_} = undef foreach keys %MRO;
        }
        _calculate_method_dispatch_tables();
        _apply_method_dispatch_tables();
        $_initialized = 1;
    }
}

sub uninitialize {
    # why bother if we don't have anything ...
    %next::METHOD_CACHE = ();
    return unless keys %MRO;    
    if($C3_IN_CORE) {
        mro::set_mro_dfs($_) for keys %MRO;
    }
    else {
        _remove_method_dispatch_tables();    
        $_initialized = 0;
    }
}

sub reinitialize { goto &initialize }

## functions for applying C3 to classes

sub _calculate_method_dispatch_tables {
    return if $C3_IN_CORE;
    my %merge_cache;
    foreach my $class (keys %MRO) {
        _calculate_method_dispatch_table($class, \%merge_cache);
    }
}

sub _calculate_method_dispatch_table {
    return if $C3_IN_CORE;
    my ($class, $merge_cache) = @_;
    no strict 'refs';
    my @MRO = calculateMRO($class, $merge_cache);
    $MRO{$class} = { MRO => \@MRO };
    my $has_overload_fallback = 0;
    my %methods;
    # NOTE: 
    # we do @MRO[1 .. $#MRO] here because it
    # makes no sense to interogate the class
    # which you are calculating for. 
    foreach my $local (@MRO[1 .. $#MRO]) {
        # if overload has tagged this module to 
        # have use "fallback", then we want to
        # grab that value 
        $has_overload_fallback = ${"${local}::()"} 
            if defined ${"${local}::()"};
        foreach my $method (grep { defined &{"${local}::$_"} } keys %{"${local}::"}) {
            # skip if already overriden in local class
            next unless !defined *{"${class}::$method"}{CODE};
            $methods{$method} = {
                orig => "${local}::$method",
                code => \&{"${local}::$method"}
            } unless exists $methods{$method};
        }
    }    
    # now stash them in our %MRO table
    $MRO{$class}->{methods} = \%methods; 
    $MRO{$class}->{has_overload_fallback} = $has_overload_fallback;        
}

sub _apply_method_dispatch_tables {
    return if $C3_IN_CORE;
    foreach my $class (keys %MRO) {
        _apply_method_dispatch_table($class);
    }     
}

sub _apply_method_dispatch_table {
    return if $C3_IN_CORE;
    my $class = shift;
    no strict 'refs';
    ${"${class}::()"} = $MRO{$class}->{has_overload_fallback}
        if $MRO{$class}->{has_overload_fallback};
    foreach my $method (keys %{$MRO{$class}->{methods}}) {
        *{"${class}::$method"} = $MRO{$class}->{methods}->{$method}->{code};
    }    
}

sub _remove_method_dispatch_tables {
    return if $C3_IN_CORE;
    foreach my $class (keys %MRO) {
        _remove_method_dispatch_table($class);
    }       
}

sub _remove_method_dispatch_table {
    return if $C3_IN_CORE;
    my $class = shift;
    no strict 'refs';
    delete ${"${class}::"}{"()"} if $MRO{$class}->{has_overload_fallback};    
    foreach my $method (keys %{$MRO{$class}->{methods}}) {
        delete ${"${class}::"}{$method}
            if defined *{"${class}::${method}"}{CODE} && 
               (*{"${class}::${method}"}{CODE} eq $MRO{$class}->{methods}->{$method}->{code});       
    }   
}

## functions for calculating C3 MRO

sub calculateMRO {
    my ($class, $merge_cache) = @_;

    return @{mro::get_mro_linear_c3($class)} if $C3_IN_CORE;

    return Algorithm::C3::merge($class, sub { 
        no strict 'refs'; 
        @{$_[0] . '::ISA'};
    }, $merge_cache);
}

package  # hide me from PAUSE
    next; 

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION = '0.06';

our %METHOD_CACHE;

sub method {
    my $self     = $_[0];
    my $class    = blessed($self) || $self;
    my $indirect = caller() =~ /^(?:next|maybe::next)$/;
    my $level = $indirect ? 2 : 1;
     
    my ($method_caller, $label, @label);
    while ($method_caller = (caller($level++))[3]) {
      @label = (split '::', $method_caller);
      $label = pop @label;
      last unless
        $label eq '(eval)' ||
        $label eq '__ANON__';
    }

    my $method;

    my $caller   = join '::' => @label;    
    
    $method = $METHOD_CACHE{"$class|$caller|$label"} ||= do {
        
        my @MRO = Class::C3::calculateMRO($class);
        
        my $current;
        while ($current = shift @MRO) {
            last if $caller eq $current;
        }
        
        no strict 'refs';
        my $found;
        foreach my $class (@MRO) {
            next if (defined $Class::C3::MRO{$class} && 
                     defined $Class::C3::MRO{$class}{methods}{$label});          
            last if (defined ($found = *{$class . '::' . $label}{CODE}));
        }
    
        $found;
    };

    return $method if $indirect;

    die "No next::method '$label' found for $self" if !$method;

    goto &{$method};
}

sub can { method($_[0]) }

package  # hide me from PAUSE
    maybe::next; 

use strict;
use warnings;

our $VERSION = '0.02';

sub method { (next::method($_[0]) || return)->(@_) }

1;
