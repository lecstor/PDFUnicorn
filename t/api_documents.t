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


# create an image for our pdf
my $url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/images');
$t->post_ok(
    $url,
    form => {
        image => { file => 't/media_directory/cory_unicorn.jpeg' },
        name => 'cory_unicorn.jpeg',
    },
)->status_is(200);


# no api-key
$url = $t->ua->server->url->path('/v1/documents');
$t->get_ok($url)->status_is(401)
    ->json_is('/type', 'invalid_request');


# empty api-key
$url = $t->ua->server->url->userinfo(":")->path('/v1/documents');
$t->get_ok($url)->status_is(401)
    ->json_is('/type', 'invalid_request');


# bad api-key
$url = $t->ua->server->url->userinfo("blah:")->path('/v1/documents');
$t->get_ok($url)->status_is(401)
    ->json_is('/type', 'invalid_request');


# bad attr in query
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->get_ok(
    $url, form => { blah => 1 }
)->status_is(422)
    ->json_is('/type', 'invalid_request')
    ->json_is('/errors', ['Unexpected object attribute: "blah"']);


# bad attr in create
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url, json => { blah => 1, source => '<doc></doc>' }
)->status_is(422)
    ->json_is('/type', 'invalid_request')
    ->json_is('/errors', ['Unexpected object attribute: "blah"']);


# bad attr and missing attr in create
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url, json => { blah => 1 }
)->status_is(422)
    ->json_is('/type', 'invalid_request')
    ->json_is('/errors', [
        'Require attribute, one of: source, template, template_id',
        'Unexpected object attribute: "blah"',
    ]);


# no attr in create
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url, json => {}
)->status_is(422)
    ->json_is('/type', 'invalid_request')
    ->json_is('/errors', [
        'Require attribute, one of: source, template, template_id',
    ]);


# no json in create
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url
)->status_is(422)
    ->json_is('/type', 'invalid_request')
    ->json_is('/errors', [
        'Require attribute, one of: source, template, template_id',
    ]);


# bad oid format
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents/not-a-valid-oid');
$t->get_ok($url)->status_is(404);


# create document
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url,
    json => {
        source => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ->json_is( '/file' => undef, "file is undef" );

my $json = $t->tx->res->json;
is $json->{uri}, '/v1/documents/'.$json->{id}, 'uri';

my $doc_uri = $json->{uri};

$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri.'.pdf');
$t->get_ok($url)->status_is(503);


# list documents
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/data/0/id', "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_is( '/data/0/uri' => $doc_uri, "has uri" )
    ->json_has( '/data/0/owner', "has owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    #->json_is( '/data/0/file' => undef, "file is undef" );
    ->json_has( '/data/0/file', "file oid is set" );


# get document meta data

$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
$t->get_ok(
    $url,
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_is( '/uri' => $json->{uri}, "has uri" )
    #->json_has( '/owner', "has owner" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="cory_unicorn.jpeg" /></page></doc>', "correct source" )
    ;
    #->json_is( '/file' => undef, "file is undef" );
    #->json_has( '/file', "file oid is set" );


$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri.'.non_format');
$t->get_ok($url)
    ->status_is(200)
    ->json_has( '/id', "has id" );
    

# get document as PDF
$url = $t->ua->server->url->userinfo("$api_key:")->path($doc_uri);
while(1){
    $t->get_ok($url.'.pdf');
    if ($t->tx->res->code == 503){
        my $retry = $t->tx->res->headers->to_hash->{'Retry-after'};
        warn "503 retry after: $retry";
        sleep($retry);
        next;
    }
    is($t->tx->res->code, 200, 'got 200');
    last;
}

$t->get_ok($url.'.pdf')->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');


# delete document
$t->delete_ok($url)->status_is(200);

# try to delete document again..
$t->delete_ok($url)->status_is(404);

$t->get_ok($url)->status_is(404);


# access documents that doesn't exist
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents/52d14181b9efb754ae040000');
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);


# create document and get response as PDF

$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents.pdf');
$t->post_ok(
    $url,
    json => { source => '<doc><page>Test 3!<img src="cory_unicorn.jpeg" /></page></doc>' },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');

#$t->tx->res->content->asset->move_to('t/api_doc.pdf');



# create document
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents.non_format');
$t->post_ok($url, json => { source => '<doc><page>Test</page></doc>' })
    ->status_is(200)
    ->json_has( '/id', "has id" );
$doc_uri = $t->tx->res->json->{uri};

# tester2 tries to access tester's images
$t->post_ok('/log-in', form => { username => 'tester2@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/rest/apikeys');
my $api_key2 = $t->tx->res->json->{data}[0]->{key};


$url = $t->ua->server->url->userinfo("$api_key2:")->path($doc_uri);
$t->get_ok($url)->status_is(404);
$t->delete_ok($url)->status_is(404);



#Mojo::IOLoop->timer(1 => sub { Mojo::IOLoop->stop });
#Mojo::IOLoop->start;

done_testing();
__END__



