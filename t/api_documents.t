use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::Util qw(b64_encode);
use Mango;
use Try;

use Data::Dumper::Perltidy;

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $documents = $mango->db->collection('documents');
try{ $documents->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);
$t->app->media_directory('t/media_directory');


# create document

$t->post_ok(
    '/api/v1/documents',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
    json => {
        id => 2,
        source => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_has( '/data/uri', "has uri" )
    ->json_is( '/data/id' => 2, "correct id" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ->json_is( '/data/file' => undef, "file is undef" );

my $json = $t->tx->res->json->{data};
is $json->{uri}, '/api/v1/documents/'.$json->{_id}, 'uri';

my $doc_uri = $json->{uri};


# list documents

$t->get_ok(
    '/api/v1/documents',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200)
    ->json_has( '/data/0/_id', "has _id" )
    ->json_has( '/data/0/modified', "has modified" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/id' => 2, "correct id" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/0/file' => undef, "file is undef" );
    ->json_has( '/data/0/file', "file oid is set" );


# get document meta data

$t->get_ok(
    $doc_uri,
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_is( '/data/id' => 2, "correct id" )
    ->json_is( '/data/uri' => $json->{uri}, "has uri" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/file' => undef, "file is undef" );
    ->json_has( '/data/file', "file oid is set" );


# get document as PDF

$t->get_ok(
    $doc_uri.'.binary',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200);

ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');

#warn $doc_uri;
#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

#$t->tx->res->content->asset->move_to('test_api_documents.pdf');

done_testing();
