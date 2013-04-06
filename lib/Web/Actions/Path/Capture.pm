use strictures 1;

package Web::Actions::Path::Capture;
use Moo;

use namespace::clean;

has name => (
    is          => 'ro',
    required    => 1,
);

sub matcher {
    my ($self) = @_;
    my $name = $self->name;
    return sub {
        my ($path, $req) = @_;
        if (@$path) {
            return [
                { $name => $path->[0] },
                [ @{ $path }[1 .. $#$path] ],
            ];
        }
        return undef;
    };
}

with qw(
    Web::Actions::Path::Matching
);

1;
