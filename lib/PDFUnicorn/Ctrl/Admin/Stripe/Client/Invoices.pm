package PDFUnicorn::Ctrl::Admin::Stripe::Client::Invoices;
use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Plugin::Stripe::Client;


=header AJAX Backend for for accessing client invoice data



=cut

=item list

GET /admin/stripe/connect/invoices

returns a list of the client's invoices

request body: {
    count => 10,    # how many to return
    created => {},  # A filter on the list based on the object created field.
    offset => 20,   # An offset into the list of returned items.
}

attributes are passed to Stripe's Invoices API

https://stripe.com/docs/api#list_customer_invoices


=cut

sub list{
    my ($self) = shift;
    my $user = $self->stash->{app_user};

    $self->render_later;
    
    $self->db_stripe_clients->find_one({ owner => $user->{_id} }, sub{
        my ($err, $client) = @_;
        
        if ($err){
            
            $self->render( ok => 0 );
            
        } else {

            my $stripe = Mojolicious::Plugin::Stripe::Client->new({
                config => { secret_api_key => $client->{access_token} },
            });
            
            my $data = $self->req->json();
            my $options = {
                count => $data->{count},
                created => $data->{created},
                offset => $data->{offset}, 
            };
            
            my $invoices = $stripe->invoices->list(
                sub{
                    my ($client, $status, $data) = @_;
                    $self->render( json => $data, status => $status );
                },
                $options
            );
            
        }
    });

}

=item find

GET /admin/stripe/connect/invoices/:invoice_id

returns a client's customer invoice

=cut

sub find{
    my ($self) = shift;
    my $user = $self->stash->{app_user};
    
    $self->render_later;

    $self->db_stripe_clients->find_one({ owner => $user->{_id} }, sub{
        my ($err, $client) = @_;
        
        if ($err){
            
            $self->render( ok => 0 );
            
        } else {

            my $stripe = Mojolicious::Plugin::Stripe::Client->new({
                config => { secret_api_key => $client->{access_token} },
            });
            
            $stripe->invoices->retrieve(
                $self->stash->{invoice_id},
                sub{
                    my ($client, $data) = @_;
                    $self->render( json => $data );
                }
            );
        
        }
    });
}



1;
