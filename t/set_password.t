use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mango;
use Try;

use List::Util 'first';

use Data::Dumper::Perltidy;

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }


my $mango = Mango->new('mongodb://127.0.0.1/pdfunicorn_test');
my $users = $mango->db->collection('users');
try{ $users->drop }

#$mango->db->collection('users')->drop;

my $t = Test::Mojo->new('PDFUnicorn');
$t->app->mango($mango);
$users = $t->app->db_users;

$t->get_ok('/')->status_is(200)->content_like(qr/PDFUnicorn/i);
    
$t->post_ok('/sign-up', => form => { name => 'Jason', email => 'jason+1@lecstor.com', time_zone => 'America/Chicago' })
    ->status_is(200)
    ->element_exists_not('input[name="name"]')
    ->element_exists_not('input[name="email"]')
    ->content_like(qr/Hey,\s+Jason,\s+thanks/)
    ->content_like(qr/jason\+1\@lecstor\.com/);


Mojo::IOLoop->timer(3 => sub {
    my @deliveries = Email::Sender::Simple->default_transport->deliveries;
    is(@deliveries, 1, 'one email delivered');
    
    my ($code, $email_hash);
    try{
        my $body = $deliveries[0]->{email}->get_body;
        ($code, $email_hash) = $body =~ /\/set-password\/(\w+)\/(\w+)/;
        ok($code, 'got code');
        ok($email_hash, 'got email hash');
    }
    
    $t->get_ok('/set-password/'.$code.'/BOGUS_EMAIL_HASH')->status_is(200)
        ->element_exists('input[name="username"]')
        ->element_exists('input[name="password"]')
        ->content_like(qr/key is invalid/)
        ->content_like(qr/Log In/);
    
    $t->get_ok('/set-password/'.$code.'/'.$email_hash)->status_is(200)
        ->element_exists('input[name="email"]')
        ->element_exists('input[name="password"]')
        ->content_like(qr/jason\+1\@lecstor\.com/)
        ->content_like(qr/Set Password/);
    
    $t->post_ok('/set-password', => form => { password => 'pass' })->status_is(302);
    $t->header_like(Location => qr/\/$/);
    
    $t->get_ok('/set-password/BOGUS_CODE/'.$email_hash)->status_is(200)
        ->element_exists('input[name="username"]')
        ->element_exists('input[name="password"]')
        ->content_like(qr/key is invalid/)
        ->content_like(qr/Log In/);
});



#warn Dumper $users->find->all;

Mojo::IOLoop->timer(6 => sub {
    $users->find_one(
        { username => 'jason+1@lecstor.com' },
        sub{
            my ($err, $doc) = @_;
            ok(!$err, 'no error');
            ok($doc);
            ok($doc->{password}, 'password: '.$doc->{password});
            return;
        }
    );
});
    

#warn Dumper $user;


done_testing();


