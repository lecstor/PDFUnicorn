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

$t->post_ok(
    '/api/v1/documents',
    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
    json => {
        id => 1,
        name => 'Test 1',
        source => '<doc>Test 1!</doc>'
    },
)->status_is(200);

$t->get_ok(
    '/api/v1/documents',
    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
)->status_is(200);

$t->get_ok(
    '/api/v1/documents/1',
    { 'Authorization' => 'PDFUToken token="1e551787-903e-11e2-b2b6-0bbccb145af3"' },
)->status_is(200);


done_testing();
