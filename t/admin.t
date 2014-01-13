use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use PDFUnicorn;
use Try;

my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $apikeys = $mango->db->collection('apikeys');
my $users = $mango->db->collection('users');
try{ $users->drop }
try{ $apikeys->drop }

my $results;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));

# inactive user
$t->post_ok('/log-in', form => { username => 'tester3@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);

$t->post_ok(
    '/admin/get-pdf',
    form => { source => '<doc><page>Test the Playground</page></doc>' },
)->status_is(401);

# active user
$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);

$t->post_ok(
    '/admin/get-pdf',
    form => { source => '<doc><page>Test the Playground</page></doc>' },
)->status_is(200);
ok($t->tx->res->body =~ /^%PDF/, 'doc is a PDF');


try{ $users->drop }


$t->post_ok(
    '/admin/get-pdf',
    form => { source => '<doc><page>Test the Playground</page></doc>' },
)->status_is(401);


done_testing();

