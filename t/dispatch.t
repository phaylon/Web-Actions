use Test::More;
use Web::Actions;
use Plack::Test;
use HTTP::Request;
use FindBin;

use lib "$FindBin::Bin/lib";

my $_prefix = 'http://localhost';

my $app = actions(
    handle('foo', GET => 'TestAction::Simple'),
    under('bar',
        handle('baz', GET => {
            class => 'TestAction::Simple',
            static => {
                text => 'in bar then baz',
            },
        }),
    ),
    under('multi/level',
        handle('dispatch/test', GET => {
            class => 'TestAction::Simple',
            static => {
                text => 'multi level testing',
            },
        }),
    ),
    under('cap-all',
        handle('any/:rest*', GET => {
            class => 'TestAction::Simple',
            call => 'run_rest',
        }),
        under('min',
            handle(':rest[2+]', GET => {
                class => 'TestAction::Simple',
                static => { prefix => 'more ' },
                call => 'run_rest',
            }),
            handle(':rest+', GET => {
                class => 'TestAction::Simple',
                static => { prefix => 'many ' },
                call => 'run_rest',
            }),
            handle(':rest*', GET => {
                class => 'TestAction::Simple',
                static => { prefix => 'any ' },
                call => 'run_rest',
            }),
        ),
    ),
    handle('cap/:capture', GET => {
        class => 'TestAction::Simple',
        call => 'run_capture',
    }),
    under('multi/cap/:capture',
        handle(':capture2/:capture3', GET => {
            class => 'TestAction::Simple',
            call => 'run_all_captures',
        }),
    ),
    root(GET => {
        class => 'TestAction::Simple',
        call => 'run_root',
    }),
)->to_psgi;

sub GET {
    my ($path, $code) = @_;
    return [HTTP::Request->new(GET => $_prefix . $path), $code];
}

sub requests {
    my @req = @_;
    return sub {
        my ($psgi_cb) = @_;
        for my $req (@req) {
            my ($req_obj, $req_test) = @$req;
            $req_test->($req_obj->$psgi_cb);
        }
    };
}

test_psgi(
    app => $app,
    client => requests(
        GET('/foo', sub {
            my $res = shift;
            like $res->content, qr{Foo\s+Result}, 'simple result';
        }),
        GET('/', sub {
            my $res = shift;
            like $res->content, qr{Root\s+Result}, 'root result';
        }),
        GET('/bar/baz', sub {
            my $res = shift;
            like $res->content, qr{in bar then baz}, 'deeper level';
        }),
        GET('/multi/level/dispatch/test', sub {
            my $res = shift;
            like $res->content, qr{multi level testing}, 'multi level';
        }),
        GET('/cap/23', sub {
            my $res = shift;
            like $res->content, qr{capture 23}, 'simple capture';
        }),
        GET('/multi/cap/23/42/17', sub {
            my $res = shift;
            like $res->content, qr{capture 23 42 17}, 'multi capture';
        }),
        GET('/cap-all/any/23/17', sub {
            my $res = shift;
            like $res->content, qr{rest 23 17}, 'capture any';
        }),
        GET('/cap-all/any', sub {
            my $res = shift;
            like $res->content, qr{rest\s*$}, 'capture none';
        }),
        GET('/cap-all/min/2/3/4/5', sub {
            my $res = shift;
            like $res->content, qr{rest more 2 3 4 5\s*$}, 'capture 4';
        }),
        GET('/cap-all/min/2/3', sub {
            my $res = shift;
            like $res->content, qr{rest more 2 3\s*$}, 'capture 2';
        }),
        GET('/cap-all/min/2', sub {
            my $res = shift;
            like $res->content, qr{rest many 2\s*$}, 'capture 1';
        }),
        GET('/cap-all/min', sub {
            my $res = shift;
            like $res->content, qr{rest any\s*$}, 'capture 0';
        }),
    ),
);

done_testing;
