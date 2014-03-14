package PDFUnicorn::Ctrl::Admin::Stripe::Client::Customers;
use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Plugin::Stripe::Client;


=header AJAX Backend for for accessing client customer data



=cut

=item list

GET /admin/stripe/connect/customers

returns a list of the client's customers

request body: {
    count => 10,    # how many to return
    created => {},  # A filter on the list based on the object created field.
    offset => 20,   # An offset into the list of returned items.
}

attributes are passed to Stripe's Customers API

https://stripe.com/docs/api#list_customers


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
            
            my $customers = $stripe->customers->list(
                sub{
                    my ($client, $data) = @_;
                    $self->render( json => $data );
                },
                $options
            );

        }
    });

}

=item find

GET /admin/stripe/connect/customers/:customer_id

returns a client's customer

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
            
            $stripe->customers->retrieve(
                $self->stash->{customer_id},
                #{ 'expand[]' => 'default_card' }, # doesn't work
                sub{
                    my ($client, $data) = @_;
                    $self->render( json => $data );
                }
            );
        
        }
    });
}



1;
