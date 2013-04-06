use strictures 1;

package Web::Actions::Path::Matching;
use Moo::Role;

use namespace::clean;

requires qw(
    matcher
);

1;
