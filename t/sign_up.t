use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mango;
use Try;

use PDFUnicorn;

use List::Util 'first';

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }


my $mango = Mango->new('mongodb://127.0.0.1/pdf_ezyapp_test');
my $users = $mango->db->collection('users');
try{ $users->drop }

#$mango->db->collection('users')->drop;

my $t = Test::Mojo->new(PDFUnicorn->new( mode => 'testing' ));
$t->app->mango($mango);


$t->get_ok('/')->status_is(200)->content_like(qr/PDFUnicorn/i);

$t->post_ok('/sign-up', => form => { firstname => 'Jason', email => '', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists('input[name="firstname"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter an email/);
    
# entered something 
$t->post_ok('/sign-up', => form => { firstname => '', email => '    ', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists('input[name="firstname"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/your real email/);

# empty form
$t->post_ok('/sign-up', => form => { firstname => '', email => '', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists('input[name="firstname"]')
    ->element_exists('input[name="email"]');
    
$t->post_ok('/sign-up', => form => { firstname => 'Jason', email => '', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists('input[name="firstname"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/enter an email/);

$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'cont@ai.ns space', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists('input[name="firstname"]')
    ->element_exists('input[name="email"]')
    ->content_like(qr/your real email/);

$t->post_ok('/sign-up', => form => { email => 'jason-test1@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'small-1' })
    ->status_is(200)
    ->element_exists_not('input[name="firstname"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+thanks/)
    ->content_like(qr/jason-test1\@lecstor\.com/);

$t->post_ok('/sign-up', => form => { firstname => 'Jason', email => 'jason-test2@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'medium-1' })
    ->status_is(200)
    ->element_exists_not('input[name="firstname"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+Jason,\s+thanks/)
    ->content_like(qr/jason-test2\@lecstor\.com/);

$t->post_ok('/sign-up', => form => { firstname => 'Jason', email => 'jason-test2@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'medium-1' })
    ->status_is(200)
    ->element_exists_not('input[name="firstname"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+Jason,\s+thanks/)
    ->content_like(qr/jason-test2\@lecstor\.com/);

my @deliveries = Email::Sender::Simple->default_transport->deliveries;
is(@deliveries, 5, 'delivered three emails');

$t->app->helper('db_users' => 'ouch');
$t->post_ok('/sign-up', => form => { email => 'jason@lecstor.com', time_zone => 'America/Chicago', selected_plan => 'medium-1' })
    ->status_is(500);


Mojo::IOLoop->timer(3 => sub { Mojo::IOLoop->stop });
Mojo::IOLoop->start;


done_testing();

