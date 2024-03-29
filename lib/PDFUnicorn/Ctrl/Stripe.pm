package PDFUnicorn::Ctrl::Stripe;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::UserAgent;
use Data::Dumper ('Dumper');


sub connect{
   	my $self = shift;
	my $code = $self->param('code');
    
    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post(
        'https://connect.stripe.com/oauth/token'
        => form => {
            client_secret => 'sk_test_HKPw1c2FnyHyUk0wGOPmzCMy', # test secret key
            code => $code,
            grant_type => 'authorization_code',
        }
    );

    my $response_data = $tx->res->json;
    if ($response_data->{error}){
        warn $response_data->{error}.': '.$response_data->{error_description};
    } else {
        my $tx = $ua->get('https://'.$response_data->{access_token}.':@api.stripe.com/v1/customers');
        my $customer_list = $tx->res->json->{data};
        my $customer = $customer_list->[0];
        #warn Dumper($customer);
        
        $tx = $ua->get(
            'https://'.$response_data->{access_token}.':@api.stripe.com/v1/invoices',
            form => { customer => $customer->{id} } 
        );

        #warn Dumper($tx->res->json);
        
    }
        
        #$VAR1 = {
        #          'scope' => 'read_only',
        #          'livemode' => bless( do{\(my $o = 0)}, 'Mojo::JSON::_Bool' ),
        #          'refresh_token' => 'rt_33nOt4KvD2GV5uGwXIfitwfwHCnlQWQ6BCKNqcfkIVEEQ313',
        #          'stripe_publishable_key' => 'pk_test_vAb8JLpH1hkfIoyeoBC55q1z',
        #          'stripe_user_id' => 'acct_1033ke2ehWbn3Xkf',
        #          'token_type' => 'bearer',
        #          'access_token' => 'sk_test_7kNHildJi0kYA2kuwsMMYvnL'
        #        };

        #$VAR1 = {
        #      'count' => 1,
        #      'object' => 'list',
        #      'url' => '/v1/customers',
        #      'data' => [
        #                {
        #                  'created' => 1386195349,
        #                  'account_balance' => 0,
        #                  'email' => 'jason@lecstor.com',
        #                  'metadata' => {},
        #                  'livemode' => bless( do{\(my $o = 0)}, 'Mojo::JSON::_Bool' ),
        #                  'subscription' => undef,
        #                  'description' => 'mild mannered internet cowboy',
        #                  'discount' => undef,
        #                  'id' => 'cus_33vn0kvXM2bvt8',
        #                  'default_card' => undef,
        #                  'object' => 'customer',
        #                  'cards' => {
        #                             'object' => 'list',
        #                             'count' => 0,
        #                             'data' => [],
        #                             'url' => '/v1/customers/cus_33vn0kvXM2bvt8/cards'
        #                           },
        #                  'delinquent' => $VAR1->{'data'}[0]{'livemode'}
        #                }
        #              ]
        #};

        #$VAR1 = {
        #    'count' => 0,
        #    'url' => '/v1/invoices',
        #    'data' => [],
        #    'object' => 'list'
        #};

        #$VAR1 = {
        #  'object' => 'list',
        #  'data' => [
        #            {
        #              'lines' => {
        #                         'url' => '/v1/invoices/in_1033wF2ehWbn3XkfpZnf8HRQ/lines',
        #                         'count' => 1,
        #                         'object' => 'list',
        #                         'data' => [
        #                                   {
        #                                     'description' => 'Test Item',
        #                                     'quantity' => undef,
        #                                     'plan' => undef,
        #                                     'currency' => 'usd',
        #                                     'type' => 'invoiceitem',
        #                                     'livemode' => bless( do{\(my $o = 0)}, 'Mojo::JSON::_Bool' ),
        #                                     'object' => 'line_item',
        #                                     'id' => 'ii_1033wE2ehWbn3XkfatBFKLjU',
        #                                     'proration' => $VAR1->{'data'}[0]{'lines'}{'data'}[0]{'livemode'},
        #                                     'metadata' => {},
        #                                     'period' => {
        #                                                 'end' => 1386196970,
        #                                                 'start' => 1386196970
        #                                               },
        #                                     'amount' => 850
        #                                   }
        #                                 ]
        #                       },
        #              'customer' => 'cus_33vn0kvXM2bvt8',
        #              'currency' => 'usd',
        #              'next_payment_attempt' => 1386200646,
        #              'closed' => $VAR1->{'data'}[0]{'lines'}{'data'}[0]{'livemode'},
        #              'subtotal' => 850,
        #              'period_start' => 1386197046,
        #              'discount' => undef,
        #              'amount_due' => 850,
        #              'object' => 'invoice',
        #              'starting_balance' => 0,
        #              'id' => 'in_1033wF2ehWbn3XkfpZnf8HRQ',
        #              'ending_balance' => undef,
        #              'paid' => $VAR1->{'data'}[0]{'lines'}{'data'}[0]{'livemode'},
        #              'attempt_count' => 0,
        #              'charge' => undef,
        #              'livemode' => $VAR1->{'data'}[0]{'lines'}{'data'}[0]{'livemode'},
        #              'period_end' => 1386197046,
        #              'date' => 1386197046,
        #              'application_fee' => undef,
        #              'total' => 850,
        #              'attempted' => $VAR1->{'data'}[0]{'lines'}{'data'}[0]{'livemode'}
        #            }
        #          ],
        #  'count' => 1,
        #  'url' => '/v1/invoices'
        #};


    
    $self->render();
}

1;
