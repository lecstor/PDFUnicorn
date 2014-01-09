use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use PDFUnicorn;
use Try;

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $users->drop }
try{ $apikeys->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));

$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);

$t->post_ok(
    '/admin/get-pdf',
    form => {
        source => '<doc><page>Test the Playground</page></doc>'
    },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');

$t->get_ok('/admin/rest/apikeys')
    ->status_is(200)
    ->json_has('/data', 'has data')
    ->json_has('/data/0', 'has data/0')
    ->json_has('/data/0/key', 'has key')
    ->json_is('/data/0/key', 'testers-api-key', 'correct key')
    ->json_is('/data/0/active', 1, 'is active');

#warn Data::Dumper->Dumper($t->tx->res->json);

my $json = $t->tx->res->json;
my $key = $json->{data}[0]{key};

$t->delete_ok('/admin/rest/apikeys/'.$key)->status_is(200);

$t->get_ok('/admin/rest/apikeys')
    ->status_is(200)
    ->json_has('/data', 'has data')
    ->json_has('/data/0', 'has data/0')
    ->json_is('/data/0/active', 1, 'is active');

#warn Data::Dumper->Dumper($t->tx->res->json);

$json = $t->tx->res->json;
my $newkey = $json->{data}[0]{key};

ok($key ne $newkey, 'new key generated');



done_testing();

