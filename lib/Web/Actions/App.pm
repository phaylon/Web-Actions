package Web::Actions::App;
use Moo;
use Web::Actions::Util qw( lazy_new );
use Web::Actions::Types qw( InstanceOf ArrayRef );
use Plack::Request;
use Safe::Isa;
use Try::Tiny;
use Carp qw( confess );

use aliased 'Web::Actions::Container::Actions', 'ActionContainer';
use aliased 'Web::Actions::Path';
use aliased 'Web::Actions::Status';

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

has catchers => (
    reader      => '_catchers_ref',
    is          => 'bare',
    isa         => ArrayRef(InstanceOf('Web::Actions::Catcher')),
    required    => 1,    
);

sub exception_handler {
    my ($self) = @_;
    my @catchable = map {
        my $catcher = $_;
        my $catches = $catcher->catches;
        $catches = [$catches]
            unless ref $catches eq 'ARRAY';
        [$catches, $catcher->handler];
    } @{ $self->_catchers_ref };
    return sub {
        my $err = shift;
        for my $catch (@catchable) {
            my ($conds, $handle) = @$catch;
            for my $cond (@$conds) {
                return $handle->($err) if do {
                    (ref $cond eq 'CODE')
                        ? $cond->($err) :
                    ($err->$_isa($cond) or $err->$_does($cond));
                };
            }
        }
        die $err;
    };
}

sub view_transformer {
    my ($self) = @_;
    my %view = map { ($_->name, $_->handler) } @{ $self->_views_ref };
    $view{__psgi} = sub { return shift };
    return sub {
        my ($res, $refs) = @_;
        my ($view_name, $view_data) = @$res;
        my @view_args;
        if (ref($view_name) eq 'ARRAY') {
            ($view_name, @view_args) = @$view_name;
        }
        confess q{View name is undefined}
            unless defined $view_name;
        my $handler = $view{$view_name}
            or confess qq{Unknown view '$view_name'};
        my $final = $handler->($view_data, $refs, @view_args);
        return $final;
    };
}

sub reference_resolver {
    my ($self) = @_;
    my %seen;
    my %by_id;
    $self->actions->traverse(sub {
        my ($path, $action, $method) = @_;
        if (defined( my $id = $action->id )) {
            confess sprintf
                    q{Action ID not unique '%s' at:\n\t%s\n\t%s\n},
                    $id,
                    $path->stringify,
                    $seen{$id}->[0]->stringify,
                if exists $seen{$id};
            $seen{$id} = [
                $path,
                $method,
                $by_id{$id} = $action->reference_builder($method, $path),
            ];
        }
    }, Path->new);
    return sub {
        my ($req, $res) = @_;
        my $action_ref_spec = $res->[2] || {};
        return +{
            (map {
                my $name = $_;
                my $spec = $action_ref_spec->{$_};
                my $id = $spec->{id}
                    or confess "Missing reference ID for link '$name'";
                my $builder = $by_id{$id};
                ($name, $builder->($req, %{ $spec->{curry} || {} }));
            } keys %$action_ref_spec),
        };
    };
}

sub _build_dispatcher {
    my ($self) = @_;
    my $action_dispatch = $self->actions->dispatcher;
    my $view_transform = $self->view_transformer;
    my $exception_handler = $self->exception_handler;
    my $ref_resolver = $self->reference_resolver;
    return sub {
        my ($env) = @_;
        try {
            my $req = Plack::Request->new($env);
            my $path_info = $req->path_info;
            $path_info =~ s{^/+}{};
            my @path = grep length, split m{/+}, $path_info;
            if (my $res = $action_dispatch->([@path], $req, {})) {
                my $refs = $ref_resolver->($req, $res);
                return $res->$view_transform($refs);
            }
            die Status->new(
                code    => 404,
                message => 'Resource not found',
            );
        }
        catch {
            return $exception_handler->($_);
        };
    };
}

sub to_psgi {
    my ($self) = @_;
    return $self->dispatcher;
}

1;
