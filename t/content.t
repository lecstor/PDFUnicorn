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


$t->get_ok('/')->status_is(200)->content_like(qr/PDFUnicorn/i);
#$t->get_ok('/features')->status_is(200)->content_like(qr/features/i);
$t->get_ok('/pricing')->status_is(200)->content_like(qr/pricing/i);
#$t->get_ok('/about')->status_is(200)->content_like(qr/about/i);


done_testing();

