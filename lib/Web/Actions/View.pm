use strictures 1;

package Web::Actions::View;
use Moo;
use Web::Actions::Types qw( Str CodeRef );

use namespace::clean;

has name => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
);

has handler => (
    is          => 'ro',
    isa         => CodeRef,
    required    => 1,
);

1;
