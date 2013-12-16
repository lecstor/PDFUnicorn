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


my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $images = $mango->db->collection('images');
my $documents = $mango->db->collection('documents');
try{ $images->drop }
try{ $documents->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);
$t->app->media_directory('t/media_directory');


# create image

$t->post_ok(
    '/api/v1/images',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
    form => {
        image => { file => 't/media_directory/1e551787-903e-11e2-b2b6-0bbccb145af3/cory_unicorn.jpeg' },
        name => '/another_cory_unicorn.jpeg',
    },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_has( '/data/uri', "has uri" )
    ->json_is( '/data/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" );


my $json = $t->tx->res->json->{data};
my $doc_uri = $json->{uri};

is $doc_uri, '/api/v1/images/'.$json->{_id}, 'uri';



# list images

$t->get_ok(
    '/api/v1/images',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200)
    ->json_has( '/data/0/_id', "has _id" )
    ->json_has( '/data/0/modified', "has modified" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/data/0/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" );


# get image meta data

$t->get_ok(
    $doc_uri.'.meta',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_has( '/data/uri', "has uri" )
    ->json_is( '/data/name' => "another_cory_unicorn.jpeg", "correct name" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" );


# get raw image

$t->get_ok(
    $doc_uri,
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200);


unlink('t/media_directory/1e551787-903e-11e2-b2b6-0bbccb145af3/another_cory_unicorn.jpeg');

#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

done_testing();
