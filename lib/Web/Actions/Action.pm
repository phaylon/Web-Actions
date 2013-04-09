use strictures 1;

package Web::Actions::Action;
use Moo;
use Web::Actions::Types qw( ClassName HashRef Str );
use Web::Actions::Util qw( lazy_require_external );
use Carp qw( confess );

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

has view => (
    is          => 'ro',
    isa         => HashRef,
    required    => 1,
);

sub _build_method { 'run' }
sub _build_constructor { 'new' }
sub _build_static_attributes { {} }

sub view_for_result {
    my ($self, $result_type) = @_;
    confess q{Undefined result type}
        unless defined $result_type;
    my $view = $self->view->{$result_type};
    confess qq{Unable to find a view for result type '$result_type'}
        unless defined $view;
    return $view;
}

sub responder {
    my ($self) = @_;
    my $class = lazy_require_external($self->class);
    my $method = $self->method;
    my $construct = $self->constructor;
    my $static = $self->_static_attributes_ref;
    return sub {
        my ($req, %path_arg) = @_;
        my $object = $class->$construct(%path_arg, %$static);
        my @result = $object->$method();
        if (@result == 1) {
            return [$self->view_for_result('ok'), $result[0]];
        }
        elsif (@result == 2) {
            return [$self->view_for_result($result[0]), $result[1]];
        }
        confess sprintf
            q{Action should return 1 or 2 values, but returned %d},
            scalar(@result);
    };
}

1;
