use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mango;
use Try;

use List::Util 'first';

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }


my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $users = $mango->db->collection('users');
try{ $users->drop }

#$mango->db->collection('users')->drop;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);


$t->get_ok('/')->status_is(200)->content_like(qr/PDFUnicorn/i);

$t->get_ok('/sign-up')->status_is(200)->content_like(qr/action="\/sign-up"/i);

$t->post_ok('/sign-up', => form => { name => 'Jason', email => '', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter an email/);
    
$t->post_ok('/sign-up', => form => { name => '', email => '    ', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/your real email/);
    
$t->post_ok('/sign-up', => form => { name => 'Jason', email => '', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter an email/);

$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'cont@ai.ns space', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/your real email/);

$t->post_ok('/sign-up', => form => { email => 'jason@lecstor.com', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists_not('input[name="name"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+thanks/)
    ->content_like(qr/jason\@lecstor\.com/);
    
$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists_not('input[name="name"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+Jason,\s+thanks/)
    ->content_like(qr/jason\+1\@lecstor\.com/);

my @deliveries = Email::Sender::Simple->default_transport->deliveries;
is(@deliveries, 2, 'delivered two emails');

$t->app->helper('db_users' => 'ouch');
$t->post_ok('/sign-up', => form => { email => 'jason@lecstor.com', time_zone => 'America/Chicago' })
    ->status_is(500);


done_testing();

