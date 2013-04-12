use strictures 1;

package Web::Actions;
use Carp qw( confess );
use Scalar::Util qw( blessed );
use Web::Actions::Util qw( lazy_require lazy_new );
use Safe::Isa;

use namespace::clean;

our $VERSION = '0.000001'; # 0.0.1
$VERSION = eval $VERSION;

use Exporter 'import';
our @EXPORT = qw( webactions handle root under view except );

my $_to_path_obj = sub {
    my ($str) = @_;
    return $str
        if blessed($str);
    return lazy_require('Path')->from_string($str);
};

my $_to_action_obj = sub {
    my ($spec) = @_;
    return $spec
        if blessed $spec;
    return lazy_new('Action', %$spec)
        if ref($spec) eq 'HASH';
    return lazy_new('Action', class => $spec)
        if defined($spec) and not ref($spec);
    confess sprintf q{Unable to convert value to action: %s},
        defined($spec) ? $spec : 'undef';
};

sub except {
    my ($cond, $handler) = @_;
    return lazy_new('Catcher', catches => $cond, handler => $handler);
}

sub view {
    my ($name, $handler) = @_;
    return lazy_new('View', name => $name, handler => $handler);
}

sub under {
    my ($path, @actions) = @_;
    return lazy_new('Group',
        path => $path->$_to_path_obj,
        actions => [@actions],
    );
}

sub webactions {
    my @actions;
    my @views;
    my @catchers;
    push @{
        $_->$_isa('Web::Actions::View')         ? \@views :
        $_->$_isa('Web::Actions::Catcher')      ? \@catchers :
        $_->$_does('Web::Actions::Dispatching') ? \@actions :
        confess(qq{Invalid webaction element})
    }, $_ for @_;
    return lazy_new('App',
        actions => \@actions,
        views => \@views,
        catchers => \@catchers,
    );
}

sub root {
    my %action = @_;
    return handle(lazy_new('Path'), %action);
}

sub handle {
    my ($path, %action) = @_;
    return lazy_new('MethodMap',
        path => $path->$_to_path_obj,
        methods => { map {
            (uc($_), $action{$_}->$_to_action_obj);
        } keys %action },
    );
}

1;

=head1 NAME

Web::Actions - Description goes here

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

 Robert Sedlacek <rs@474.at>

=head1 CONTRIBUTORS

None yet - maybe this software is perfect! (ahahahahahahahahaha)

=head1 COPYRIGHT

Copyright (c) 2013 the Web::Actions L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.
