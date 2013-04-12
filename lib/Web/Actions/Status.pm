use strictures 1;

package Web::Actions::Status;
use Moo;
use Web::Actions::Types qw( HTTPStatusCode Value );

use namespace::clean;

has code => (
    is          => 'ro',
    isa         => HTTPStatusCode,
    required    => 1,
);

has message => (
    is          => 'ro',
    isa         => Value,
    required    => 1,
);

1;
