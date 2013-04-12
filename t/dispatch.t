use Test::More;
use Web::Actions;
use Plack::Test;
use HTTP::Request;
use FindBin;
use HTTP::Request::Common ();

use lib "$FindBin::Bin/lib";

my $_prefix = 'http://localhost';

my $app = webactions(
    view(raw => sub {
        my $res = shift;
        return [200, ['Content-Type', 'text/html'], [$res]];
    }),
    except('Web::Actions::Status', sub {
        my $err = shift;
        return [
            $err->code,
            ['Content-Type', 'text/html'],
            [$err->message],
        ];
    }),
    handle('foo', GET => {
        class => 'TestAction::Simple',
        view => { ok => 'raw' },
    }),
    under('param',
        handle('query', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            query_params => {
                'param1' => 'foo',
            },
        }),
        handle('query_req', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            query_params => {
                'param1' => '!foo',
            },
        }),
        handle('query_list', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            query_params => {
                'param1' => '@foo',
            },
        }),
        handle('body', POST => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            body_params => {
                'param1' => 'foo',
            },
        }),
        handle('body_req', POST => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            body_params => {
                'param1' => '!foo',
            },
        }),
        handle('body_list', POST => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_params',
            body_params => {
                'param1' => '@foo',
            },
        }),
    ),
    under('bar',
        handle('baz', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            static => {
                text => 'in bar then baz',
            },
        }),
    ),
    under('multi/level',
        handle('dispatch/test', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            static => {
                text => 'multi level testing',
            },
        }),
    ),
    under('cap-all',
        handle('any/:rest*', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_rest',
        }),
        under('min',
            handle(':rest[2+]', GET => {
                class => 'TestAction::Simple',
                view => { ok => 'raw' },
                static => { prefix => 'more ' },
                call => 'run_rest',
            }),
            handle(':rest+', GET => {
                class => 'TestAction::Simple',
                view => { ok => 'raw' },
                static => { prefix => 'many ' },
                call => 'run_rest',
            }),
            handle(':rest*', GET => {
                class => 'TestAction::Simple',
                view => { ok => 'raw' },
                static => { prefix => 'any ' },
                call => 'run_rest',
            }),
        ),
    ),
    handle('cap/:capture', GET => {
        class => 'TestAction::Simple',
        view => { ok => 'raw' },
        call => 'run_capture',
    }),
    under('multi/cap/:capture',
        handle(':capture2/:capture3', GET => {
            class => 'TestAction::Simple',
            view => { ok => 'raw' },
            call => 'run_all_captures',
        }),
    ),
    root(GET => {
        class => 'TestAction::Simple',
        view => { ok => 'raw' },
        call => 'run_root',
    }),
)->to_psgi;

my $_wrap = sub {
    my ($path, $code, $method) = @_;
    return sub {
        my @args = @_;
        subtest "request $method $path", sub {
            $code->(@args);
            done_testing;
        };
    };
};

sub REQUEST {
    my ($method, $path, $code) = @_;
    return [
        HTTP::Request->new($method => $_prefix . $path),
        $_wrap->($path, $code, $method),
    ];
}

sub POST {
    my ($path, $params, $code) = @_;
    return [
        HTTP::Request::Common::POST($path, $params),
        $_wrap->($path, $code, 'POST'),
    ];
}

sub GET {
    my ($path, $code) = @_;
    return [
        HTTP::Request->new(GET => $_prefix . $path),
        $_wrap->($path, $code, 'GET'),
    ];
}

sub OPTIONS {
    my ($path, @opt) = @_;
    return [
        HTTP::Request->new(OPTIONS => $_prefix . $path),
        $_wrap->($path, sub {
            my $res = shift;
            is_deeply
                [sort split m{\s*,\s*}, $res->header('Allow')],
                [sort(@opt, 'OPTIONS')],
                'available options';
        }, 'OPTIONS'),
    ];
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
        REQUEST(FNORD => '/foo', sub {
            my $res = shift;
            is $res->code, 405, 'status code';
            like $res->content, qr{Invalid request method}i, 'message';
        }),
        GET('/doesnotexist', sub {
            my $res = shift;
            is $res->code, 404, 'status code';
            like $res->content, qr{Resource not found}, 'message';
        }),
        GET('/', sub {
            my $res = shift;
            like $res->content, qr{Root\s+Result}, 'root result';
        }),
        OPTIONS('/', 'GET'),
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
        ##
        ##  parameters
        ##
        GET('/param/query?foo=23', sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=23}, 'query param';
        }),
        GET('/param/query_req?foo=23', sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=23}, 'query param';
        }),
        GET('/param/query_req?bar=23', sub {
            my $res = shift;
            is $res->code, 400, 'request fail';
            like $res->content, qr{parameter.+foo}, 'query param';
        }),
        GET('/param/query_list', sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@$}, 'query param';
        }),
        GET('/param/query_list?foo=23', sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@23$}, 'query param';
        }),
        GET('/param/query_list?foo=23&foo=17', sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@23,17$}, 'query param';
        }),
        POST('/param/body', [foo => 23], sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=23}, 'query param';
        }),
        POST('/param/body_req', [foo => 23], sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=23}, 'query param';
        }),
        POST('/param/body_req', [bar => 23], sub {
            my $res = shift;
            is $res->code, 400, 'request fail';
            like $res->content, qr{parameter.+foo}, 'query param';
        }),
        POST('/param/body_list', [], sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@$}, 'query param';
        }),
        POST('/param/body_list', [foo => 23], sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@23$}, 'query param';
        }),
        POST('/param/body_list', [foo => 23, foo => 17], sub {
            my $res = shift;
            is $res->code, 200, 'request ok';
            like $res->content, qr{param1=\@23,17$}, 'query param';
        }),
    ),
);

done_testing;
