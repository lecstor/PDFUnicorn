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

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $documents = $mango->db->collection('documents');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $documents->drop }
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
my $owner_id = $api_key_data->{owner};


# create an image for our pdf
my $url = $t->ua->server->url->userinfo("$api_key:")->path('/api/v1/images');
$t->post_ok(
    $url,
    form => {
        image => { file => 't/media_directory/cory_unicorn.jpeg' },
        name => 'cory_unicorn.jpeg',
    },
)->status_is(200);

# create document

$url = $t->ua->server->url->userinfo("$api_key:")->path('/api/v1/documents');
$t->post_ok(
    $url,
    json => {
        source => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/modified', "has modified" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_is( '/owner' => $owner_id, "correct owner" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ->json_is( '/file' => undef, "file is undef" );

my $json = $t->tx->res->json;
is $json->{uri}, '/api/v1/documents/'.$json->{id}, 'uri';

my $doc_uri = $json->{uri};


# list documents

$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/modified', "has modified" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_is( '/data/0/owner' => $owner_id, "correct owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/0/file' => undef, "file is undef" );
    ->json_has( '/data/0/file', "file oid is set" );


# get document meta data

$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/modified', "has modified" )
    ->json_has( '/created', "has created" )
    ->json_is( '/uri' => $json->{uri}, "has uri" )
    ->json_is( '/owner' => $owner_id, "correct owner" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/file' => undef, "file is undef" );
    ->json_has( '/file', "file oid is set" );



# get document as PDF

$t->get_ok(
    $url.'.binary',
)->status_is(200);

ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');


# create document and get response as PDF

$url = $t->ua->server->url->userinfo("$api_key:")->path('/api/v1/documents.binary');
$t->post_ok(
    $url,
    json => { source => '<doc><page>Test 3!<img src="cory_unicorn.jpeg" /></page></doc>' },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');



#warn $doc_uri;
#warn $t->tx->res->body;

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');

#$t->tx->res->content->asset->move_to('test_api_documents.pdf');

Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;

done_testing();
__END__



