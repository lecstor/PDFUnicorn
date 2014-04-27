use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mango::BSON ':bson';

use Mango;
use Try;

use PDFUnicorn;

use Data::Dumper::Perltidy;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $stripe_clients = $mango->db->collection('db_stripe_clients');
my $users = $mango->db->collection('users');
try{ $stripe_clients->drop }
try{ $users->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));
#$t->app->mango($mango);


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);

# log in as user with password set..
$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);


# create stripe client
$t->post_ok(
    '/admin/rest/stripe_clients',
    json => {
        access_token => 'access_token123',
        refresh_token => 'refresh_token123',
        stripe_publishable_key => 'stripe_publishable_key123',
        stripe_user_id => 'stripe_user_id123',
        token_type => 'token_type123',
        scope => 'scope123',
        livemode => bson_false,
        #template_id => { type => 'oid', bson => 'oid' },
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_is( '/access_token' => 'access_token123', "access_token" )
    ->json_is( '/refresh_token' => 'refresh_token123', "refresh_token" )
    ->json_is( '/stripe_publishable_key' => 'stripe_publishable_key123', "stripe_publishable_key" )
    ->json_is( '/stripe_user_id' => 'stripe_user_id123', "stripe_user_id" )
    ->json_is( '/token_type' => 'token_type123', "token_type" )
    ->json_is( '/scope' => 'scope123', "scope" );

my $json = $t->tx->res->json;
is $json->{uri}, '/v1/stripe_clients/'.$json->{id}, 'uri';

my $doc_id = $json->{id};


# list stripe_clients
$t->get_ok(
    '/admin/rest/stripe_clients',
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_has( '/data/0/uri', "has uri" )
    ->json_has( '/data/0/owner', "has owner" )
    ->json_is( '/data/0/access_token' => 'access_token123', "access_token" )
    ->json_is( '/data/0/refresh_token' => 'refresh_token123', "refresh_token" )
    ->json_is( '/data/0/stripe_publishable_key' => 'stripe_publishable_key123', "stripe_publishable_key" )
    ->json_is( '/data/0/stripe_user_id' => 'stripe_user_id123', "stripe_user_id" )
    ->json_is( '/data/0/token_type' => 'token_type123', "token_type" )
    ->json_is( '/data/0/scope' => 'scope123', "scope" );

# get stripe_client

$t->get_ok(
    '/admin/rest/stripe_clients/'.$doc_id,
)->status_is(200)
    ->json_is( '/id' => $doc_id, "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_is( '/access_token' => 'access_token123', "access_token" )
    ->json_is( '/refresh_token' => 'refresh_token123', "refresh_token" )
    ->json_is( '/stripe_publishable_key' => 'stripe_publishable_key123', "stripe_publishable_key" )
    ->json_is( '/stripe_user_id' => 'stripe_user_id123', "stripe_user_id" )
    ->json_is( '/token_type' => 'token_type123', "token_type" )
    ->json_is( '/scope' => 'scope123', "scope" );



# delete stripe_client
$t->delete_ok('/admin/rest/stripe_clients/'.$doc_id)->status_is(200);

# try to delete stripe_client again..
$t->delete_ok('/admin/rest/stripe_clients/'.$doc_id)->status_is(404);

$t->get_ok('/admin/rest/stripe_clients/'.$doc_id)->status_is(404);


# access document that doesn't exist
$t->get_ok('/admin/rest/stripe_clients/52d14181b9efb754ae040000')->status_is(404);
$t->delete_ok('/admin/rest/stripe_clients/52d14181b9efb754ae040000')->status_is(404);


# tester2 tries to access tester's templates
$t->post_ok('/log-in', form => { username => 'tester2@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/rest/stripe_clients');
my $api_key2 = $t->tx->res->json->{data}[0]->{key};

$t->get_ok('/admin/rest/stripe_clients/'.$doc_id)->status_is(404);
$t->delete_ok('/admin/rest/stripe_clients/'.$doc_id)->status_is(404);





done_testing();
