use strictures 1;

package Web::Actions::Group;
use Moo;
use Web::Actions::Types qw( InstanceOf );

use aliased 'Web::Actions::Container::Actions', 'ActionContainer';

use namespace::clean;

has path => (
    is          => 'ro',
    isa         => InstanceOf('Web::Actions::Path'),
    required    => 1,
);

has actions => (
    is          => 'ro',
    isa         => InstanceOf(ActionContainer),
    coerce      => ActionContainer->coercion,
    default     => sub { ActionContainer->new },
);

sub traverse {
    my ($self, $callback, $parent_path) = @_;
    my $path = $parent_path->append($self->path);
    return $self->actions->traverse($callback, $path);
}

sub dispatcher {
    my ($self) = @_;
    my $path_matcher = $self->path->matcher;
    my $action_dispatcher = $self->actions->dispatcher;
    return sub {
        my ($path, $req, $collected) = @_;
        if (my $accept = $path_matcher->($path)) {
            my ($extract, $rest) = @$accept;
            my $new_data = { %$collected, %$extract };
            return $action_dispatcher->($rest, $req, $new_data);
        }
        return undef;
    };
}

with qw(
    Web::Actions::Dispatching
);

1;
