use strictures 1;

package TestAction::Simple;
use Moo;

use namespace::clean;

has text => (is => 'ro');
has capture => (is => 'ro');
has capture2 => (is => 'ro');
has capture3 => (is => 'ro');
has rest => (is => 'ro');
has prefix => (is => 'ro');
has param1 => (is => 'ro');
has param2 => (is => 'ro');

sub run {
    my ($self) = @_;
    return $self->text || 'Foo Result';
}

sub run_params {
    my ($self) = @_;
    return join ' ', map {
        my $method = $_;
        my $value = $self->$method;
        join '=', $method, ref($value) ? '@'.join(',', @$value) : $value;
    } grep { defined $self->$_ } qw( param1 param2 );
}

sub run_root {
    my ($self) = @_;
    return 'Root Result';
}

sub run_capture {
    my ($self) = @_;
    return 'capture ' . $self->capture;
}

sub run_all_captures {
    my ($self) = @_;
    return
        'capture ' . join ' ',
            $self->capture,
            $self->capture2,
            $self->capture3;
}

sub run_rest {
    my ($self) = @_;
    return sprintf 'rest %s%s',
        $self->prefix || '',
        join ' ', @{ $self->rest };
}

1;
