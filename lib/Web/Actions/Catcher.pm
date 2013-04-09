use strictures 1;

package Web::Actions::Catcher;
use Moo;
use Web::Actions::Types qw( Value CodeRef );

use namespace::clean;

has code => (
    is          => 'ro',
    isa         => Value,
    required    => 1,
);

has handler => (
    is          => 'ro',
    isa         => CodeRef,
    required    => 1,
);

1;
