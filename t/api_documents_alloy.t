use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

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


# create document with template source and get response as PDF
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents.pdf');
$t->post_ok(
    $url,
    json => {
        data => { image => "cory_unicorn.jpeg" },
        template => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>'
    },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');


# create a template
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/templates');
$t->post_ok(
    $url,
    json => {
        name => 'Test 2', 
        source => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>'
    },
)->status_is(200);
my $template_id = $t->tx->res->json->{id};


# create document with template id and get response as PDF
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents.pdf');
$t->post_ok(
    $url,
    json => {
        data => { image => "cory_unicorn.jpeg" },
        template_id => $template_id
    },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');


# create document with template id and get response as metadata
$url = $t->ua->server->url->userinfo("$api_key:")->path('/v1/documents');
$t->post_ok(
    $url,
    json => {
        data => { image => "cory_unicorn.jpeg" },
        template_id => $template_id
    },
)->status_is(200);

my $json = $t->tx->res->json;

# get document as PDF
$url = $t->ua->server->url->userinfo("$api_key:")->path($json->{uri});
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


done_testing();
