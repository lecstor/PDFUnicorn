use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::Util qw(b64_encode);
use Mango;
use Try;

use PDFUnicorn;

use Data::Dumper::Perltidy;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdf_ezyapp_test');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $apikeys->drop }
try{ $users->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));
#$t->app->mango($mango);


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);

# haven't set password, so no access
$t->get_ok('/admin/api-key')->status_is(401);
$t->get_ok('/admin/rest/apikeys')->status_is(401);

# log in as user with password set..
$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);


# REST API

# get key

$t->get_ok('/admin/rest/apikeys')
    ->status_is(200)
    ->json_has('/data', 'has data')
    ->json_has('/data/0', 'has data/0')
    ->json_has('/data/0/key', 'has key')
    ->json_is('/data/0/key', 'testers-api-key', 'correct key')
    ->json_is('/data/0/active', 1, 'is active');

my $json = $t->tx->res->json;
my $key = $json->{data}[0]{key};

# delete key

$t->delete_ok('/admin/rest/apikeys/'.$key)->status_is(200);

# get new key

$t->get_ok('/admin/rest/apikeys')
    ->status_is(200)
    ->json_has('/data', 'has data')
    ->json_has('/data/0', 'has data/0')
    ->json_is('/data/0/active', 1, 'is active');

$json = $t->tx->res->json;
my $newkey = $json->{data}[0]{key};

ok($key ne $newkey, 'new key generated');

$t->put_ok("/admin/rest/apikeys/$newkey", json => { active => 0 })
    ->status_is(200)
    ->json_is('/active', 0, 'is active');

$t->put_ok("/admin/rest/apikeys/$newkey", json => { active => 1 })
    ->status_is(200)
    ->json_is('/active', 1, 'is active');


$t->get_ok('/admin/api-key')
    ->status_is(200);

$t->delete_ok('/admin/rest/apikeys/'.$newkey)->status_is(200);

$t->get_ok('/admin/api-key')
    ->status_is(200);




done_testing();
