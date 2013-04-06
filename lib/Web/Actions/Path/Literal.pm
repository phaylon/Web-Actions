use strictures 1;

package Web::Actions::Path::Literal;
use Moo;
use Web::Actions::Types qw( PathPartStr );

use namespace::clean;

has value => (
    is          => 'ro',
    isa         => PathPartStr,
    required    => 1,
);

sub matcher {
    my ($self) = @_;
    my $value = $self->value;
    return sub {
        my ($path, $req) = @_;
        if (@$path and $path->[0] eq $value) {
            return [{}, [@{ $path }[1 .. $#$path]]];
        }
        return undef;
    };
}

with qw(
    Web::Actions::Path::Matching
);

1;
