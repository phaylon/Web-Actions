use strictures 1;

package Web::Actions::Action;
use Moo;
use Web::Actions::Types qw( ClassName HashRef Str );
use Web::Actions::Util qw( lazy_require_external );
use Carp qw( confess );

use aliased 'Web::Actions::Status';

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

has body_parameters => (
    is          => 'bare',
    reader      => '_bparams',
    isa         => HashRef,
    lazy        => 1,
    builder     => '_build_body_parameters',
    init_arg    => 'body_params',
);

has query_parameters => (
    is          => 'bare',
    reader      => '_qparams',
    isa         => HashRef,
    lazy        => 1,
    builder     => '_build_query_parameters',
    init_arg    => 'query_params',
);

has view => (
    is          => 'ro',
    isa         => HashRef,
    required    => 1,
);

sub _build_method { 'run' }
sub _build_constructor { 'new' }
sub _build_static_attributes { {} }
sub _build_body_parameters { {} }
sub _build_query_parameters { {} }

sub view_for_result {
    my ($self, $result_type) = @_;
    confess q{Undefined result type}
        unless defined $result_type;
    my $view = $self->view->{$result_type};
    confess qq{Unable to find a view for result type '$result_type'}
        unless defined $view;
    return $view;
}

sub _make_parameter_parser {
    my ($self, $spec) = @_;
    my (%name_map, %is_list, %is_required);
    if (ref $spec eq 'ARRAY') {
        $name_map{$_} = $_
            for @$spec;
    }
    elsif (ref $spec eq 'HASH') {
        for my $attr (keys %$spec) {
            my $source = $spec->{$attr};
            if ($source =~ s{^([@!])}{}) {
                (($1 eq '@') ? \%is_list : \%is_required)->{$attr} = 1;
            }
            $name_map{$attr} = $source;
        }
    }
    else {
        confess qq{Invalid parameter specification '$spec'};
    }
    return sub {
        my ($params) = @_;
        return {}
            unless keys %name_map;
        my %param_data;
        for my $attr (keys %name_map) {
            my $param = $name_map{$attr};
            if (exists $params->{$param}) {
                $param_data{$attr} = $is_list{$attr}
                    ? [$params->get_all($param)]
                    : $params->get($param);
            }
            else {
                if ($is_required{$attr}) {
                    die Status->new(
                        code => 400,
                        message => qq{Missing parameter '$param'},
                    );
                }
                if ($is_list{$attr}) {
                    $param_data{$attr} = [];
                }
            }
        }
        return \%param_data;
    };
}

sub responder {
    my ($self) = @_;
    my $class = lazy_require_external($self->class);
    my $method = $self->method;
    my $construct = $self->constructor;
    my $static = $self->_static_attributes_ref;
    my $bparam = $self->_make_parameter_parser($self->_bparams);
    my $qparam = $self->_make_parameter_parser($self->_qparams);
    return sub {
        my ($req, %path_arg) = @_;
        my $object = $class->$construct(
            %path_arg,
            %$static,
            %{ $bparam->($req->body_parameters) },
            %{ $qparam->($req->query_parameters) },
        );
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
