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
