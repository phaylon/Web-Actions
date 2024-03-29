use strictures 1;

package Web::Actions::MethodMap;
use Moo;
use Web::Actions::Types qw( HTTPMethod Responding Map InstanceOf );
use Web::Actions::Util qw( lazy_new );

use aliased 'Web::Actions::Status';

use namespace::clean;

has path => (
    is          => 'ro',
    isa         => InstanceOf('Web::Actions::Path'),
    required    => 1,
);

has method_map => (
    is          => 'bare',
    reader      => '_method_map',
    isa         => Map(HTTPMethod, InstanceOf('Web::Actions::Action')),
    init_arg    => 'methods',
    required    => 1,
);

sub action_for_method { $_[0]->_method_map->{$_[1]} }
sub methods { sort keys %{ $_[0]->_method_map } }
sub actions { map $_[0]->_method_map->{$_}, $_[0]->methods }
sub has_actions { scalar keys %{ $_[0]->_method_map } }

sub traverse {
    my ($self, $callback, $parent_path) = @_;
    my $path = $parent_path->append($self->path);
    $self->action_for_method($_)->traverse($callback, $path, $_)
        for $self->methods;
    return 1;
}

sub dispatcher {
    my ($self) = @_;
    my $path_matcher = $self->path->end_matcher;
    my %method_map = map {
        my $method = $_;
        my $action = $self->action_for_method($method);
        ($method, $action->responder);
    } $self->methods;
    return sub {
        my ($path, $req, $collected) = @_;
        if (my $extract = $path_matcher->($path)) {
            my $method = uc($req->method);
            if ($method eq 'OPTIONS') {
                return [__psgi => [200, [
                    'Allow' => join(', ',
                        'OPTIONS',
                        keys %method_map,
                    ),
                ], []]];
            }
            elsif (my $responder = $method_map{$method}) {
                return $responder->($req, %$collected, %$extract);
            }
            else {
                die Status->new(
                    code    => 405,
                    message => 'Invalid request method',
                );
            }
        }
        return undef;
    };
}

with qw(
    Web::Actions::Dispatching
    Web::Actions::Responding
);

1;
