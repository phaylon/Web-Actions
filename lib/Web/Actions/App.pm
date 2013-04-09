package Web::Actions::App;
use Moo;
use Web::Actions::Util qw( lazy_new );
use Web::Actions::Types qw( InstanceOf ArrayRef );
use Plack::Request;
use Carp qw( confess );

use aliased 'Web::Actions::Container::Actions', 'ActionContainer';

use namespace::clean;

has dispatcher => (
    is          => 'ro',
    init_arg    => undef,
    lazy        => 1,
    builder     => '_build_dispatcher',
);

has actions => (
    is          => 'ro',
    isa         => InstanceOf(ActionContainer),
    coerce      => ActionContainer->coercion,
    default     => sub { ActionContainer->new },
);

has views => (
    reader      => '_views_ref',
    is          => 'bare',
    isa         => ArrayRef(InstanceOf('Web::Actions::View')),
    required    => 1,
);

sub view_transformer {
    my ($self) = @_;
    my %view = map { ($_->name, $_->handler) } @{ $self->_views_ref };
    $view{__psgi} = sub { return shift };
    return sub {
        my $res = shift;
        my ($view_name, $view_data) = @$res;
        my @view_args;
        if (ref($view_name) eq 'ARRAY') {
            ($view_name, @view_args) = @$view_name;
        }
        confess q{View name is undefined}
            unless defined $view_name;
        my $handler = $view{$view_name}
            or confess qq{Unknown view '$view_name'};
        my $final = $handler->($view_data, @view_args);
        return $final;
    };
}

sub _build_dispatcher {
    my ($self) = @_;
    my $action_dispatch = $self->actions->dispatcher;
    my $view_transform = $self->view_transformer;
    return sub {
        my $req = Plack::Request->new(shift);
        my $path_info = $req->path_info;
        $path_info =~ s{^/+}{};
        my @path = grep length, split m{/+}, $path_info;
        if (my $res = $action_dispatch->([@path], $req, {})) {
            return $res->$view_transform;
        }
        http_throw(NotFound => {
            message => 'Resource not found',
        });
    };
}

sub to_psgi {
    my ($self) = @_;
    return $self->dispatcher;
}

1;
