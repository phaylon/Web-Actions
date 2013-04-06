use strictures 1;

package Web::Actions::Dispatching;
use Moo::Role;

use namespace::clean;

requires qw(
    dispatcher
);

1;
