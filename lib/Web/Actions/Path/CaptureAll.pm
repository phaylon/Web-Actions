use strictures 1;

package Web::Actions::Path::CaptureAll;
use Moo;
use Carp qw( confess );

use namespace::clean;

has name => (
    is          => 'ro',
    required    => 1,
);

has minimum => (
    is          => 'ro',
    default     => sub { 0 },
);

sub stringify {
    my ($self) = @_;
    return sprintf ':%s[%d+]', $self->name, $self->minimum;
}

sub make_builder {
    my ($self) = @_;
    my $name = $self->name;
    my $min = $self->minimum;
    return sub {
        my ($ref) = @_;
        my @values = $ref->curried_list($name);
        confess qq{Not enough values for capture-all path part '$name'}
            if @values < $min;
        return join '/', @values;
    };
}

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
