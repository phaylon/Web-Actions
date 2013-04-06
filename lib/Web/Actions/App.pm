package Web::Actions::App;
use Moo;
use Web::Actions::Util qw( lazy_new );
use Web::Actions::Types qw( InstanceOf );
use Plack::Request;

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

sub _build_dispatcher {
    my ($self) = @_;
    my $action_dispatch = $self->actions->dispatcher;
    return sub {
        my $req = Plack::Request->new(shift);
        my $path_info = $req->path_info;
        $path_info =~ s{^/+}{};
        my @path = grep length, split m{/+}, $path_info;
        if (my $res = $action_dispatch->([@path], $req, {})) {
            return $res;
        }
        return [
            404,
            ['Content-Type' => 'text/plain'],
            ['404 - Not found'],
        ];
    };
}

sub to_psgi {
    my ($self) = @_;
    return $self->dispatcher;
}

1;
