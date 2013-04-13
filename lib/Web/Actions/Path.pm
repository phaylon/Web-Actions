use strictures 1;

package Web::Actions::Path;
use Moo;
use Web::Actions::Types qw( PathMatching ArrayRef );
use Web::Actions::Util qw( lazy_new );
use Safe::Isa;
use Carp qw( confess );

use namespace::clean;

has parts => (
    is          => 'bare',
    reader      => '_parts_ref',
    isa         => ArrayRef(PathMatching),
    default     => sub { [] },
);

sub parts { @{ $_[0]->_parts_ref } }
sub part { $_[0]->_parts_ref->[$_[1]] }
sub has_parts { scalar $_[0]->parts }

my $_rx_ident = qr{(?:[a-zA-Z_][a-zA-Z0-9_]*)};

sub stringify {
    my ($self) = @_;
    return sprintf '/%s', join '/', map $_->stringify, $self->parts;
}

sub make_builder {
    my ($self) = @_;
    my @part_builders = map $_->make_builder, $self->parts;
    return sub {
        my $ref = shift;
        return join '/', map $_->($ref), @part_builders;
    };
}

sub from_string {
    my ($class, $str) = @_;
    my @parts = map {
        my $item = $_;
        ($item =~ m{^:($_rx_ident)$})
            ? lazy_new('Path::Capture', name => $1) :
        ($item =~ m{^:($_rx_ident)\*$})
            ? lazy_new('Path::CaptureAll', name => $1) :
        ($item =~ m{^:($_rx_ident)\+$})
            ? lazy_new('Path::CaptureAll', name => $1, minimum => 1) :
        ($item =~ m{^:($_rx_ident)\[([1-9]\d*)\+\]$})
            ? lazy_new('Path::CaptureAll', name => $1, minimum => $2) :
        lazy_new('Path::Literal', value => $item);
    } split m{/}, $str;
    return $class->new(parts => \@parts);
}

sub append {
    my ($self, $other) = @_;
    my $class = ref $self;
    return $class->new(parts => [
        $self->parts,
        $other->$_isa(__PACKAGE__)
            ? $other->parts :
        (ref($other) eq 'ARRAY')
            ? @$other :
        confess('Unable to concatenate path with invalid object'),
    ]);
}

sub matcher {
    my ($self) = @_;
    my @part_matchers = map $_->matcher, $self->parts;
    return sub {
        my ($path) = @_;
        my %collected;
        for my $matcher (@part_matchers) {
            my $accepted = $matcher->($path)
                or return undef;
            my ($extract, $rest) = @$accepted;
            $path = $rest;
            %collected = (%collected, %$extract);
        }
        return [\%collected, $path];
    };
}

sub end_matcher {
    my ($self) = @_;
    my $matcher = $self->matcher;
    return sub {
        my ($path) = @_;
        my $accepted = $matcher->($path)
            or return undef;
        my ($extract, $rest) = @$accepted;
        return undef
            if @$rest;
        return $extract;
    };
}

1;
