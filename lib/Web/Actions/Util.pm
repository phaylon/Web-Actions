use strictures 1;

package Web::Actions::Util;
use Module::Runtime qw( use_module );

use namespace::clean;

use Exporter 'import';

our @EXPORT_OK = qw( lazy_require lazy_require_external lazy_new );

sub lazy_require {
    my ($class) = @_;
    return use_module(join '::', 'Web::Actions', $class);
}

sub lazy_new {
    my ($class, @args) = @_;
    return lazy_require($class)->new(@args);
}

sub lazy_require_external {
    my ($class) = @_;
    return use_module($class);
}

1;
