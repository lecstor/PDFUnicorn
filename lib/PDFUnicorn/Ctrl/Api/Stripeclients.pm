package PDFUnicorn::Ctrl::Api::Stripeclients;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use Mojo::IOLoop;

sub collection{ shift->db_stripe_clients }

sub uri{ 'stripe_clients' }
sub item_schema{ 'StripeClient' }
sub query_schema{ 'StripeClientQuery' }

1;
