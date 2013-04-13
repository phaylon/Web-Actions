use strictures 1;

package Web::Actions::Container::Actions;
use Moo;
use Safe::Isa;
use Web::Actions::Types qw( Dispatching ArrayRef );
use Carp qw( confess );

use aliased 'Web::Actions::Path';

use namespace::clean;

has actions => (
    is          => 'bare',
    reader      => '_actions_ref',
    isa         => ArrayRef(Dispatching),
    required    => 1,
);

sub all { @{ $_[0]->_actions_ref } }
sub get { $_[0]->_actions_ref->[$_[1]] }
sub count { scalar $_[0]->actions }

sub traverse {
    my ($self, $callback, $path) = @_;
    $_->traverse($callback, $path)
        for $self->all;
    return 1;
}

sub dispatcher {
    my ($self) = @_;
    my @subdispatchers = map $_->dispatcher, $self->all;
    return sub {
        my ($path, $req, $collected) = @_;
        for my $dispatcher (@subdispatchers) {
            if (my $res = $dispatcher->($path, $req, $collected)) {
                return $res;
            }
        }
        return undef;
    };
}

sub coercion {
    my ($class) = @_;
    return sub {
        my $value = shift;
        return $value
            if $value->$_isa(__PACKAGE__);
        return $class->new(actions => $value)
            if ref($value) eq 'ARRAY';
        confess q{Unable to coerce from non-array reference};
    };
}

1;
