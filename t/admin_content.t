use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
#use Mango;

#BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }
#
#
#my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
#my $users = $mango->db->collection('users');
#try{ $users->drop }

#$mango->db->collection('users')->drop;

my $t = Test::Mojo->new('PDFUnicorn');
#$t->app->mango($mango);

$t->post_ok('/log-in', form => { username => 'tester@pdfunicorn.com', password => 'bogus' })
    ->status_is(302);

$t->get_ok('/admin/billing')->status_is(200)->content_like(qr/Billing/i);
$t->get_ok('/admin/personal')->status_is(200)->content_like(qr/Personal/i);
$t->get_ok('/admin/api-docs')->status_is(200)->content_like(qr/API Documentation/i);

done_testing();

