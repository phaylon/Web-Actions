use Test::More;
use Web::Actions;
use FindBin;

use lib "$FindBin::Bin/lib";

my $app = actions(
    handle('foo', GET => 'TestAction::Simple'),
);

isa_ok $app, 'Web::Actions::App', 'application object';
is $app->has_actions, 1, 'single top level action';
my $map = $app->action(0);
isa_ok $map, 'Web::Actions::MethodMap', 'method mapping';

my $path = $map->path;
isa_ok $path, 'Web::Actions::Path', 'path';
is $path->has_parts, 1, 'single part';
my $part1 = $path->part(0);
isa_ok $part1, 'Web::Actions::Path::Literal', 'literal path item';
is $part1->value, 'foo', 'literal value';

is $map->has_actions, 1, 'single method action';
is_deeply [$map->methods], ['GET'], 'mapped method';
my $get = $map->action_for_method('GET');
isa_ok $get, 'Web::Actions::Action', 'action';

done_testing;
