use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
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

$t->post_ok(
    '/api/v1/documents',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
    json => {
        id => 1,
        name => 'Test 1',
        source => '<doc><page>Test 1!</page></doc>'
    },
)->status_is(200);
my $json = $t->tx->res->json->{data};
is $json->{id}, 1, 'id';
is $json->{source}, '<doc><page>Test 1!</page></doc>', 'source';
is $json->{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
is $json->{name}, 'Test 1', 'name';
ok $json->{uri}, 'uri';
ok $json->{_id}, 'mongo id';
ok $json->{created}, 'created';
ok $json->{modified}, 'modified';
ok !$json->{file}, 'file';

my $doc_id = $json->{_id};

$t->get_ok(
    '/api/v1/documents',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200);
$json = $t->tx->res->json->{data};
is ref($json), 'ARRAY', 'is a list';
is $json->[0]{id}, 1, 'id';
is $json->[0]{source}, '<doc><page>Test 1!</page></doc>', 'source';
is $json->[0]{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
is $json->[0]{name}, 'Test 1', 'name';
is $json->[0]{uri}, '/api/v1/documents/'.$doc_id, 'correct uri';
ok $json->[0]{_id}, 'mongo id';
ok $json->[0]{created}, 'created';
ok $json->[0]{modified}, 'modified';
ok $json->[0]{file}, 'file';


$t->get_ok(
    '/api/v1/documents/'.$doc_id,
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200);

$json = $t->tx->res->json->{data};
is $json->{id}, 1, 'id';
is $json->{source}, '<doc><page>Test 1!</page></doc>', 'source';
is $json->{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
is $json->{name}, 'Test 1', 'name';
is $json->{uri}, '/api/v1/documents/'.$doc_id, 'correct uri';
ok $json->{_id}, 'mongo id';
ok $json->{created}, 'created';
ok $json->{modified}, 'modified';
ok $json->{file}, 'file';



$t->post_ok(
    '/api/v1/documents',
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
    json => {
        id => 2,
        name => 'Test 2',
        source => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_has( '/data/uri', "has uri" )
    ->json_is( '/data/name' => "Test 2", "correct name" )
    ->json_is( '/data/id' => 2, "correct id" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ->json_is( '/data/file' => undef, "file is undef" );

$json = $t->tx->res->json->{data};
is $json->{uri}, '/api/v1/documents/'.$json->{_id}, 'uri';


my $doc_uri = $json->{uri};

$t->get_ok(
    $doc_uri,
    { 'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3' },
)->status_is(200)
    ->json_has( '/data/_id', "has _id" )
    ->json_has( '/data/modified', "has modified" )
    ->json_has( '/data/created', "has created" )
    ->json_is( '/data/name' => "Test 2", "correct name" )
    ->json_is( '/data/id' => 2, "correct id" )
    ->json_is( '/data/uri' => $json->{uri}, "has uri" )
    ->json_is( '/data/owner' => "1e551787-903e-11e2-b2b6-0bbccb145af3", "correct owner" )
    ->json_is( '/data/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/file' => undef, "file is undef" );
    ->json_has( '/data/file', "file oid is set" );


$t->get_ok(
    $doc_uri,
    {
        'Authorization' => 'Basic 1e551787-903e-11e2-b2b6-0bbccb145af3',
        'Accept' => 'application/pdf'
    },
)->status_is(200);

#warn Dumper($t->tx->res);


#$t->tx->res->asset->move_to('test_api_documents.pdf');
$t->tx->res->content->asset->move_to('test_api_documents.pdf');

#Mojo::IOLoop->timer(3 => sub { done_testing(); });
    
#my $file = Mojo::Asset::File->new;

done_testing();
