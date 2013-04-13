use strictures 1;

package Web::Actions::Path::Capture;
use Moo;
use Carp qw( confess );

use namespace::clean;

has name => (
    is          => 'ro',
    required    => 1,
);

sub stringify {
    my ($self) = @_;
    return sprintf ':%s', $self->name;
}

sub make_builder {
    my ($self) = @_;
    my $name = $self->name;
    return sub {
        my $value = $_[0]->curried_item($name);
        confess qq{Missing path capture argument '$name'}
            unless defined $value;
        return $value;
    };
}

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
