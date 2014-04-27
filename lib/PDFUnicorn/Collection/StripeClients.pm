package PDFUnicorn::Collection::StripeClients;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'StripeClient', {
            owner => { type => 'oid', bson => 'oid' },
            access_token => { type => 'string' },
            refresh_token => { type => 'string' },
            stripe_publishable_key => { type => 'string' },
            stripe_user_id => { type => 'string' },
            token_type => { type => 'string' },
            scope => { type => 'string' },
            livemode => { type => 'boolean', bson => 'bool' },
            template_id => { type => 'oid', bson => 'oid' },
        },
        'StripeClientQuery', {
            id => { type => 'string' },
        }
    }
}



1;
