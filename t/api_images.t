use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mango;
use Try;

use PDFUnicorn;

use Data::Dumper::Perltidy;

# Disable IPv6, epoll and kqueue
# BEGIN { $ENV{MOJO_NO_IPV6} = $ENV{MOJO_POLL} = 1 }

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdf_ezyapp_test');
my $images = $mango->db->collection('images');
my $documents = $mango->db->collection('documents');
my $users = $mango->db->collection('users');
try{ $users->drop }
try{ $images->drop }
try{ $documents->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));
$t->app->mango($mango);
$t->app->config->{media_directory} = 't/media_directory';


$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/api-key');
$t->get_ok('/admin/rest/apikeys');
my $api_key_data = $t->tx->res->json->{data}[0];
my $api_key = $api_key_data->{key};


# create image
my $url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/images');
$t->post_ok(
    $url,
    form => {
        image => { file => 't/media_directory/cory_unicorn.jpeg' },
        src => '/unicorn.jpg',
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_hasnt( '/_id', "has no _id" )
    ->json_is( '/src' => "unicorn.jpg", "correct src" )
    ->json_has( '/owner', "has owner" );


my $json = $t->tx->res->json;
my $doc_uri = $json->{uri};

is $doc_uri, '/v1/images/'.$json->{id}, 'uri';

# create stock image
$t->post_ok(
    $url,
    form => {
        image => { file => 't/media_directory/cory_unicorn.jpeg' },
        src => '/unicorn2.jpg',
        stock => 1,
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_hasnt( '/_id', "has no _id" )
    ->json_is( '/src' => "unicorn2.jpg", "correct src" )
    ->json_is( '/stock' => 1, "correct stock" )
    ->json_has( '/owner', "has owner" );

$json = $t->tx->res->json;
my $doc_uri2 = $json->{uri};


# forget to send image
$t->post_ok($url, form => { src => '/unicorn2.jpg' })
    ->status_is(422)
    ->json_is('/type' => 'invalid_request')
    ->json_is('/errors/0' => 'There was no file data in the upload request.');



# list images
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/src' => "unicorn.jpg", "correct src" );


# list filtered images
$t->get_ok(
    $url.'?stock=1',
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri2, "has uri" )
    ->json_is( '/data/0/src' => "unicorn2.jpg", "correct src" );


# get image meta data
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->get_ok($url)
    ->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_is( '/src' => "unicorn.jpg", "correct src" )
    ->json_has( '/owner', "has owner" );

$t->get_ok($url.'404')
    ->status_is(404);

# get raw image
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri.'.img');
$t->get_ok($url)->status_is(200);

# delete image
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->delete_ok($url)->status_is(200);

# try to delete image again
$t->delete_ok($url)->status_is(404);


# access images that doesn't exist
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/images/52d14181b9efb754ae040000');
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);


# tester2 tries to get tester's image
$t->post_ok('/log-in', form => { username => 'tester2@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/rest/apikeys');
$api_key = $t->tx->res->json->{data}[0]->{key};

$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri2);
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);


#unlink('t/media_directory/1e551787-903e-11e2-b2b6-0bbccb145af3/unicorn.jpg');

#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

done_testing();
