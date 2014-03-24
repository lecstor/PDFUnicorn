package PDFUnicorn::Ctrl::Admin::Stripe::Client::Invoices;
use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Plugin::Stripe::Client;


=header AJAX Backend for for accessing client invoice data



=cut

=item list

GET /admin/stripe/connect/invoices

returns a list of the client's invoices

request body: {
    count: 10,    # how many to return
    created: {},  # A filter on the list based on the object created field.
    offset: 20,   # An offset into the list of returned items.
    expand[]: 'data.customer',
    customer:  'cus_3G9DKxyV0h9qj1'
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

            if ($client){
                my $stripe = Mojolicious::Plugin::Stripe::Client->new({
                    config => { secret_api_key => $client->{access_token} },
                });
                
                my $data = $self->req->params->to_hash();
                my $options = {};
                $options->{count} = $data->{count} if $data->{count};
                $options->{created} = $data->{created} if $data->{created};
                $options->{offset} = $data->{offset} if $data->{offset};
                $options->{customer} = $data->{customer} if $data->{customer};
                $options->{'expand[]'} = $data->{'expand[]'} if $data->{'expand[]'};
                                
                my $invoices = $stripe->invoices->list(
                    sub{
                        my ($client, $status, $data) = @_;
                        $self->render( json => $data, status => $status );
                    },
                    $options
                );
            } else {
                $self->render( json => {}, status => 200 );
            }            
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
