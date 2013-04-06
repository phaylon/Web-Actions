use strictures 1;

package Web::Actions::Action;
use Moo;
use Web::Actions::Types qw( ClassName );
use Web::Actions::Util qw( lazy_require_external );

use namespace::clean;

has class => (
    is          => 'ro',
    isa         => ClassName,
    required    => 1,
);

has constructor => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_build_constructor',
);

has method => (
    is          => 'ro',
    lazy        => 1,
    init_arg    => 'call',
    builder     => '_build_method',
);

has static_attributes => (
    is          => 'bare',
    reader      => '_static_attributes_ref',
    lazy        => 1,
    builder     => '_build_static_attributes',
    init_arg    => 'static',
);

sub _build_method { 'run' }
sub _build_constructor { 'new' }
sub _build_static_attributes { {} }

sub responder {
    my ($self) = @_;
    my $class = lazy_require_external($self->class);
    my $method = $self->method;
    my $construct = $self->constructor;
    my $static = $self->_static_attributes_ref;
    return sub {
        my ($req, %path_arg) = @_;
        my $object = $class->$construct(%path_arg, %$static);
        return $object->$method();
    };
}

1;
