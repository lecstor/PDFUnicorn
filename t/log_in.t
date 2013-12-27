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

$t->get_ok('/admin')->status_is(401);

$t->get_ok('/log-in')->status_is(200); #->content_like(qr/action="\/log-in"/i);

$t->post_ok('/log-in', => form => { username => 'Jason', password => 'something' })
    ->status_is(200)
    ->element_exists('input[name="username"]')
    ->element_exists('input[name="password"]')
    ->content_like(qr/enter an email/);

$t->post_ok('/sign-up', => form => {
    name => 'Jason',
    email => 'jason+1@lecstor.com',
    time_zone => 'America/Chicago'
})->status_is(200);

$t->get_ok('/admin')->status_is(200);
$t->get_ok('/admin?get-started')->status_is(200);

my @deliveries = Email::Sender::Simple->default_transport->deliveries;
my $body = $deliveries[0]->{email}->get_body;
my ($code, $email_hash) = $body =~ /\/set-password\/(\w+)\/(\w+)/;

$t->get_ok('/set-password/'.$code.'/'.$email_hash)->status_is(200);
$t->post_ok('/admin/set-password', => form => { password => 'pass' })->status_is(302);


$t->get_ok('/log-out')->status_is(302);

#$t->get_ok('/app')->status_is(302);

$t->post_ok('/log-in', => form => { username => 'jason+1@lecstor.com', password => 'wrong' })
    ->status_is(200)
    ->element_exists('input[name="username"]')
    ->element_exists('input[name="password"]')
    ->content_like(qr/that password is incorrect/);
    
$t->post_ok('/log-in', => form => { username => 'jason+1@lecstor.com', password => 'pass' })
    ->status_is(302);

#$t->get_ok('/app')->status_is(200);

#done_testing();


$t->post_ok('/sign-up', => form => { name => '', email => '    ', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter your real email/);
    
$t->post_ok('/sign-up', => form => { name => 'Jason', email => '', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter an email/);

$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'cont@ai.ns space', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists('input[name="name"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter your real email/);

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

@deliveries = Email::Sender::Simple->default_transport->deliveries;
is(@deliveries, 3);


done_testing();

