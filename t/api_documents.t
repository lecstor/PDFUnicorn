use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mango;
use Try;

use Data::Dumper::Perltidy;

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $documents = $mango->db->collection('documents');
try{ $documents->drop }

my $results;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);

#$t->post_ok(
#    '/api/v1/documents',
#    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
#    json => {
#        id => 1,
#        name => 'Test 1',
#        source => '<doc><page>Test 1!</page></doc>'
#    },
#)->status_is(200);
#my $json = $t->tx->res->json;
#is $json->{id}, 1, 'id';
#is $json->{source}, '<doc><page>Test 1!</page></doc>', 'source';
#is $json->{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
#is $json->{name}, 'Test 1', 'name';
#is $json->{uri}, '/v1/documents/1', 'url';
#ok $json->{_id}, 'mongo id';
#ok $json->{created}, 'created';
#ok $json->{modified}, 'modified';
#ok !$json->{file}, 'file';
#
#
#$t->get_ok(
#    '/api/v1/documents',
#    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
#)->status_is(200);
#$json = $t->tx->res->json;
#is ref($json), 'ARRAY', 'is a list';
#is $json->[0]{id}, 1, 'id';
#is $json->[0]{source}, '<doc><page>Test 1!</page></doc>', 'source';
#is $json->[0]{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
#is $json->[0]{name}, 'Test 1', 'name';
#is $json->[0]{uri}, '/v1/documents/1', 'url';
#ok $json->[0]{_id}, 'mongo id';
#ok $json->[0]{created}, 'created';
#ok $json->[0]{modified}, 'modified';
#ok $json->[0]{file}, 'file';
#
#
#$t->get_ok(
#    '/api/v1/documents/1',
#    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
#)->status_is(200);
#
#$json = $t->tx->res->json;
#is $json->{id}, 1, 'id';
#is $json->{source}, '<doc><page>Test 1!</page></doc>', 'source';
#is $json->{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
#is $json->{name}, 'Test 1', 'name';
#is $json->{uri}, '/v1/documents/1', 'url';
#ok $json->{_id}, 'mongo id';
#ok $json->{created}, 'created';
#ok $json->{modified}, 'modified';
#ok $json->{file}, 'file';
#

### Images

$t->post_ok(
    '/api/v1/documents',
    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
    json => {
        id => 2,
        name => 'Test 2',
        source => '<doc><page>Test 2!<img src="/hello/to/you" /></page></doc>'
    },
)->status_is(200);
my $json = $t->tx->res->json;
is $json->{id}, 2, 'id';
is $json->{source}, '<doc><page>Test 2!<img src="/hello/to/you" /></page></doc>', 'source';
is $json->{owner}, '1e551787-903e-11e2-b2b6-0bbccb145af3', 'owner';
is $json->{name}, 'Test 2', 'name';
is $json->{uri}, '/v1/documents/2', 'url';
ok $json->{_id}, 'mongo id';
ok $json->{created}, 'created';
ok $json->{modified}, 'modified';
ok !$json->{file}, 'no file';

#$t = $t->finish_ok;
$t = $t->finished_ok();

#sleep(10);

warn "Tests done!";

done_testing();
