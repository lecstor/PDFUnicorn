use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mango;
use Try;

use Data::Dumper::Perltidy;

# Disable IPv6, epoll and kqueue
# BEGIN { $ENV{MOJO_NO_IPV6} = $ENV{MOJO_POLL} = 1 }

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $images = $mango->db->collection('images');
my $documents = $mango->db->collection('documents');
try{ $images->drop }
try{ $documents->drop }
my $users = $mango->db->collection('users');
try{ $users->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);
$t->app->config->{media_directory} = 't/media_directory';


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);
$t->get_ok('/admin/api-key');
$t->get_ok('/admin/rest/apikeys');
my $api_key_data = $t->tx->res->json->{data}[0];
my $api_key = $api_key_data->{key};
my $owner_id = $api_key_data->{owner};



# create image
my $url = $t->ua->server->url->userinfo("$api_key:")->path('/api/v1/images');

$t->post_ok(
    $url,
    form => {
        image => { file => 't/media_directory/cory_unicorn.jpeg' },
        name => '/another_cory_unicorn.jpeg',
    },
)->status_is(200)
    ->json_has( '/_id', "has _id" )
    ->json_has( '/modified', "has modified" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_is( '/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/owner' => $owner_id, "correct owner" );


my $json = $t->tx->res->json;
my $doc_uri = $json->{uri};

is $doc_uri, '/api/v1/images/'.$json->{_id}, 'uri';



# list images

$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/data/0/_id', "has _id" )
    ->json_has( '/data/0/modified', "has modified" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/data/0/owner' => $owner_id, "correct owner" );


# get image meta data
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri.'.meta');

$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/_id', "has _id" )
    ->json_has( '/modified', "has modified" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_is( '/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/owner' => $owner_id, "correct owner" );


# get raw image
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);

$t->get_ok($url)->status_is(200);

unlink('t/media_directory/1e551787-903e-11e2-b2b6-0bbccb145af3/another_cory_unicorn.jpeg');

#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

done_testing();
