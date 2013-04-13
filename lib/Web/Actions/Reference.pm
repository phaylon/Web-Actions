use strictures 1;

package Web::Actions::Reference;
use Moo;
use URI;
use Carp qw( confess );

use namespace::clean;

has method => (
    is          => 'ro',
    required    => 1,
);

has base => (
    is          => 'bare',
    reader      => '_base_uri',
    required    => 1,
);

has curried => (
    is          => 'bare',
    reader      => '_curried_ref',
    lazy        => 1,
    default     => sub { {} },
);

has body_parameters => (
    is          => 'bare',
    reader      => '_body_parameters_ref',
    default     => sub { {} },
);

has query_parameters => (
    is          => 'bare',
    reader      => '_query_parameters_ref',
    default     => sub { {} },
);

has path_builder => (
    is          => 'bare',
    reader      => '_path_builder_cb',
    required    => 1,
);

sub _clone {
    my ($self, $curry) = @_;
    return ref($self)->new(
        method => $self->method,
        body_parameters => $self->_body_parameters_ref,
        query_parameters => $self->_query_parameters_ref,
        path_builder => $self->_path_builder_cb,
        base => $self->_base_uri,
        curried => {
            %{ $self->_curried_ref },
            (map {
                my $key = $_;
                my $value = $curry->{$key};
                defined($value)
                    ? ($key, ref($value) ? $value : [$value])
                    : ();
            } keys %$curry),
        },
    );
}

sub uri {
    my ($self, %curry) = @_;
    return $self->_clone(\%curry)->uri
        if keys %curry;
    my $base = '' . $self->_base_uri;
    $base =~ s{/+$}{};
    my $path = $self->_path_builder_cb->($self);
    my $param = $self->_construct_query_params;
    return URI->new("$base/$path$param");
}

sub _construct_query_params {
    my ($self) = @_;
    my @params = map {
        my $attr = $_;
        my $spec = $self->_query_parameters_ref->{$_};
        my $param = $spec->{param};
        my $is_list = $spec->{is_list};
        my $is_required = $spec->{is_required};
        $is_list
            ? (map { [$param, $_] } $self->curried_list($attr))
            : do {
                my $value = $self->curried_item($attr);
                defined($value)
                    ? ([$param, $value])
                    : $is_required
                        ? confess(qq{Missing parameter '$param'})
                        : ();
            };
    } keys %{ $self->_query_parameters_ref };
    return ''
        unless @params;
    return sprintf '?%s', join '&', map sprintf('%s=%s', @$_), @params;
}

sub curried_list {
    my ($self, $attr) = @_;
    my $cache = $self->_curried_ref;
    if (exists $cache->{$attr}) {
        my $value = $cache->{$attr};
        return @$value;
    }
    return;
}

sub curried_item {
    my ($self, $attr) = @_;
    my $cache = $self->_curried_ref;
    if (exists $cache->{$attr}) {
        my $value = $cache->{$attr};
        return(
            (@$value == 1)
                ? $value->[0]
                : confess qq{Invalid number of values for '$attr'}
        );
    }
    return undef;
}

1;
