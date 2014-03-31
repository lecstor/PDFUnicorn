use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
#use Mojo::Asset::File;
#use Mojo::IOLoop;
#use Mojo::Util qw(b64_encode);
use Mango;
use Try;

use PDFUnicorn;

use Data::Dumper::Perltidy;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $templates = $mango->db->collection('templates');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $templates->drop }
try{ $apikeys->drop }
try{ $users->drop }

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


# create template
my $url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/templates');
$t->post_ok(
    $url,
    json => {
        name => 'Test 2', 
        source => '<doc><page>Test 2!<img src="{{ image }}" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_has( '/name', "Test 2" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="{{ image }}" /></page></doc>', "correct source" )
    ->json_is( '/file' => undef, "file is undef" );

my $json = $t->tx->res->json;
is $json->{uri}, '/v1/templates/'.$json->{id}, 'uri';

my $doc_uri = $json->{uri};


# update template
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->put_ok(
    $url,
    json => {
        name => 'Test 2', 
        source => '<doc><page>Test 2! with update <img src="{{ image }}" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_has( '/name', "Test 2" )
    ->json_is( '/source' => '<doc><page>Test 2! with update <img src="{{ image }}" /></page></doc>', "correct source" )
    ->json_is( '/file' => undef, "file is undef" );

$json = $t->tx->res->json;
is $json->{uri}, '/v1/templates/'.$json->{id}, 'uri';



# list templates
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/templates');
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_has( '/data/0/owner', "has owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="{{ image }}" /></page></doc>', "correct source" )
    ;


# get template meta data

$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_is( '/uri' => $json->{uri}, "has uri" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="{{ image }}" /></page></doc>', "correct source" )
    ;



# delete template
$t->delete_ok($url)->status_is(200);

# try to delete document again..
$t->delete_ok($url)->status_is(404);

$t->get_ok($url)->status_is(404);


# access documents that doesn't exist
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents/52d14181b9efb754ae040000');
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);


# tester2 tries to access tester's images
$t->post_ok('/log-in', form => { username => 'tester2@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/rest/apikeys');
my $api_key2 = $t->tx->res->json->{data}[0]->{key};

$url = $t->ua->server->url->userinfo("$api_key2:")->path($doc_uri);
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);


done_testing();
__END__



