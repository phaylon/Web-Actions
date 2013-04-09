use strictures 1;

package Web::Actions::Types;
use Safe::Isa;
use Try::Tiny;

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw(
    Dispatching
    Responding
    PathMatching
    HTTPMethod
    ArrayRef
    HashRef
    Map
    Str
    PathPartStr
    InstanceOf
    ClassName
    CodeRef
);

my $_role_type = sub {
    my ($role) = @_;
    return sub {
        die "Not an object implementing '$role'\n"
            unless $_[0]->$_does($role);
    };
};

my $_enum_type = sub {
    my @values = @_;
    return sub {
        die sprintf "Value must be one of %s\n", join ', ', @values
            unless grep { $_ eq $_[0] } @values;
    };
};

my $_tc_dispatching = 'Web::Actions::Dispatching'->$_role_type;
my $_tc_responding = 'Web::Actions::Responding'->$_role_type;
my $_tc_path_matching = 'Web::Actions::Path::Matching'->$_role_type;

my $_tc_http_method = $_enum_type->(qw(
    GET
    HEAD
    POST
    PUT
    DELETE
    PATCH
));

my $_tc_str = sub {
    die "Not a string\n"
        unless defined($_[0]) and not ref($_[0]);
};

my $_tc_path_part_str = sub {
    $_tc_str->($_[0]);
    die "String contains newlines\n"
        if $_[0] =~ m{\n};
};

my $_tc_class_name = sub {
    $_tc_str->($_[0]);
    die "Class name contains newlines\n"
        if $_[0] =~ m{\n};
    die "Class name contains spaces\n"
        if $_[0] =~ m{\s};
};

my $_tc_code_ref = sub {
    die "Not a code reference\n"
        unless ref($_[0]) eq 'CODE';
};

sub Dispatching { $_tc_dispatching }
sub Responding { $_tc_responding }
sub PathMatching { $_tc_path_matching }
sub HTTPMethod { $_tc_http_method }
sub Str { $_tc_str }
sub PathPartStr { $_tc_str }
sub ClassName { $_tc_class_name }
sub CodeRef { $_tc_code_ref }

sub InstanceOf {
    my ($class) = @_;
    return sub {
        die "Not an instance of '$class'\n"
            unless $_[0]->$_isa($class);
    };
}

sub Map {
    my ($tc_key, $tc_value) = @_;
    if ($tc_key or $tc_value) {
        return sub {
            my ($value) = @_;
            die "Not a hash reference\n"
                unless ref($value) eq 'HASH';
            my @errors;
            for my $key (sort keys %$value) {
                if ($tc_key) {
                    try {
                        $tc_key->($key);
                    }
                    catch {
                        push @errors, [key => $key, $_];
                    };
                }
                if ($tc_value) {
                    try {
                        $tc_value->($value->{$key});
                    }
                    catch {
                        push @errors, [value => $key, $_];
                    };
                }
            }
            die sprintf "Invalid hash reference content:\n%s",
                (map {
                    my ($type, $key, $error) = @$_;
                    ($type eq 'key')
                        ? "\tKey '$key': $error\n"
                        : "\tValue for key '$key': $error\n";
                } @errors),
                if @errors;
        };
    }
    else {
        return sub {
            my ($value) = @_;
            die "Not a hash reference\n"
                unless ref($value) eq 'HASH';
        };
    }
}

sub HashRef {
    my ($tc_value) = @_;
    return Map(undef, $tc_value);
}

sub ArrayRef {
    my ($tc_item) = @_;
    if ($tc_item) {
        return sub {
            my ($value) = @_;
            die "Not an array reference\n"
                unless ref($value) eq 'ARRAY';
            my @errors;
            for my $index (0 .. $#$value) {
                try {
                    $tc_item->($value->[$index]);
                }
                catch {
                    push @errors, [$index, $_];
                };
            }
            die sprintf "Invalid array reference content:\n%s",
                (map {
                    my ($index, $error) = @$_;
                    chomp $error;
                    "\t[$index] $error\n";
                } @errors),
                if @errors;
        };
    }
    else {
        return sub {
            die "Not an array reference\n"
                unless ref($_[0]) eq 'ARRAY';
        };
    }
}

1;
