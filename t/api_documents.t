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
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $documents->drop }
try{ $apikeys->drop }
try{ $users->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);
$t->app->media_directory('t/media_directory');


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago' })
    ->status_is(200);
$t->get_ok('/admin/api-key');
$t->get_ok('/admin/rest/apikeys');
my $api_key_data = $t->tx->res->json->{data}[0];
my $api_key = $api_key_data->{key};
my $owner_id = $api_key_data->{owner};

warn "api_key: $api_key owner_id: $owner_id";

my $headers = { 'Authorization' => "Basic $api_key" };

# create an image for our pdf
$t->post_ok(
    '/api/v1/images',
    $headers,
    form => {
        image => { file => 't/media_directory/1e551787-903e-11e2-b2b6-0bbccb145af3/cory_unicorn.jpeg' },
        name => 'cory_unicorn.jpeg',
    },
)->status_is(200);


# create document

$t->post_ok(
    '/api/v1/documents',
    $headers,
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
    ->json_is( '/data/owner' => $owner_id, "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ->json_is( '/data/file' => undef, "file is undef" );

#warn Data::Dumper->Dumper($t->tx->res);

my $json = $t->tx->res->json->{data};
is $json->{uri}, '/api/v1/documents/'.$json->{_id}, 'uri';

my $doc_uri = $json->{uri};


# list documents

$t->get_ok(
    '/api/v1/documents',
    $headers,
)->status_is(200)
    ->json_has( '/data/0/_id', "has _id" )
    ->json_has( '/data/0/modified', "has modified" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/id' => 2, "correct id" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/owner' => $owner_id, "correct owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/0/file' => undef, "file is undef" );
    ->json_has( '/data/0/file', "file oid is set" );


# get document meta data

$t->get_ok(
    $doc_uri,
    $headers,
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_is( '/data/id' => 2, "correct id" )
    ->json_is( '/data/uri' => $json->{uri}, "has uri" )
    ->json_is( '/data/owner' => $owner_id, "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/file' => undef, "file is undef" );
    ->json_has( '/data/file', "file oid is set" );


# get document as PDF

$t->get_ok(
    $doc_uri.'.binary',
    $headers,
)->status_is(200);

ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');

#warn $doc_uri;
#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

#$t->tx->res->content->asset->move_to('test_api_documents.pdf');

done_testing();
