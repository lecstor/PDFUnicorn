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
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $apikeys->drop }
try{ $users->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));
#$t->app->mango($mango);


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);

# haven't set password, so no access
$t->get_ok('/admin/api-key')->status_is(401);
$t->get_ok('/admin/rest/apikeys')->status_is(401);

# log in as user with password set..
$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);


# create template
$t->post_ok(
    '/admin/rest/templates',
    json => {
        name => 'Test 2', 
        source => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>'
    },
)->status_is(200)
    ->json_has( '/id', "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_has( '/owner', "has owner" )
    ->json_has( '/name', "Test 2" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>', "correct source" )
    ->json_is( '/file' => undef, "file is undef" );

my $json = $t->tx->res->json;
is $json->{uri}, '/v1/templates/'.$json->{id}, 'uri';

my $doc_id = $json->{id};


# list templates
$t->get_ok(
    '/admin/rest/templates',
)->status_is(200)
    ->json_is( '/data/0/id' => $doc_id, "has id" )
    ->json_has( '/data/0/created', "has created" )
    ->json_has( '/data/0/uri', "has uri" )
    ->json_has( '/data/0/owner', "has owner" )
    ->json_is( '/data/0/source' => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>', "correct source" )
    ;


# get template meta data

$t->get_ok(
    '/admin/rest/templates/'.$doc_id,
)->status_is(200)
    ->json_is( '/id' => $doc_id, "has id" )
    ->json_has( '/created', "has created" )
    ->json_has( '/uri', "has uri" )
    ->json_is( '/source' => '<doc><page>Test 2!<img src="[% image %]" /></page></doc>', "correct source" )
    ;



# delete template
$t->delete_ok('/admin/rest/templates/'.$doc_id)->status_is(200);

# try to delete document again..
$t->delete_ok('/admin/rest/templates/'.$doc_id)->status_is(404);

$t->get_ok('/admin/rest/templates/'.$doc_id)->status_is(404);


# access documents that doesn't exist
$t->get_ok('/admin/rest/templates/52d14181b9efb754ae040000')->status_is(404);
$t->delete_ok('/admin/rest/templates/52d14181b9efb754ae040000')->status_is(404);


# tester2 tries to access tester's templates
$t->post_ok('/log-in', form => { username => 'tester2@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);
$t->get_ok('/admin/rest/templates');
my $api_key2 = $t->tx->res->json->{data}[0]->{key};

$t->get_ok('/admin/rest/templates/'.$doc_id)->status_is(404);
$t->delete_ok('/admin/rest/templates/'.$doc_id)->status_is(404);





done_testing();
