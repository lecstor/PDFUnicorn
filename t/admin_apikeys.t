use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::Asset::File;
use Mojo::IOLoop;
use Mojo::Util qw(b64_encode);
use Mango;
use Try;

use Data::Dumper::Perltidy;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $apikeys->drop }
try{ $users->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);

# no api-key exists, so one will be created
$t->get_ok('/admin/rest/apikeys');
my $api_key_data = $t->tx->res->json->{data}[0];
ok($api_key_data, 'api-key exists');
ok($api_key_data->{key}, 'key has key');
ok($api_key_data->{owner}, 'key has owner');

# key already exists, no need to create
$t->get_ok('/admin/rest/apikeys');
$api_key_data = $t->tx->res->json->{data}[0];
ok($api_key_data, 'api-key exists');
ok($api_key_data->{key}, 'key has key');
ok($api_key_data->{owner}, 'key has owner');


$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+2@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200);


# no api-key exists, so one will be created
$t->get_ok('/admin/api-key')->status_is(200);

# api-key exists
$t->get_ok('/admin/api-key')->status_is(200);


done_testing();
