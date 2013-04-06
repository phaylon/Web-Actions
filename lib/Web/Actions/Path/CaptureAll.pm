use strictures 1;

package Web::Actions::Path::CaptureAll;
use Moo;

use namespace::clean;

has name => (
    is          => 'ro',
    required    => 1,
);

has minimum => (
    is          => 'ro',
    default     => sub { 0 },
);

sub matcher {
    my ($self) = @_;
    my $name = $self->name;
    my $min = $self->minimum;
    return sub {
        my ($path) = @_;
        if (@$path >= $min) {
            return [
                { $name => [@$path] },
                [],
            ];
        }
        return undef;
    };
}

with qw(
    Web::Actions::Path::Matching
);

1;
