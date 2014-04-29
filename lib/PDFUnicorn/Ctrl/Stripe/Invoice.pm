package PDFUnicorn::Ctrl::Stripe::Invoice;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use JSON;

use Mango::BSON ':bson';
#use Mojo::ByteStream 'b';

use lib '../PDF-Grid/lib';

use PDF::Grid;
use Mojolicious::Plugin::Stripe::Client;

use Data::Dumper 'Dumper';


sub home{
	my $self = shift;
	$self->render();
}

sub pdf{
    my $self = shift;

    my $mode = $self->stash->{'client_mode'} || 'live';
    
    my $client_key = $self->stash->{'client_pub_key'}
    if ($client_key !~ /^pk_/){ $client_key = "pk_${mode}_$client_key";
    
    my $invoice_id = $self->stash->{'invoice_id'};
    if ($invoice_id !~ /^in_/){ $invoice_id = "in_$invoice_id";
    
    my $delay = Mojo::IOLoop::Delay->new->data({
        client_key => $client_key,
        invoice_id => $invoice_id
    });
    
    $self->render_later;

    $delay->steps(
        sub {
            # find the stripe client
            my $delay = shift;
            $self->db_stripe_clients->find_one(
                { stripe_publishable_key => $delay->data('client_key') },
                $delay->begin
            );
        },
        sub {
            my ($delay, $stripe_client) = @_;
            $delay->pass($stripe_client);
            
            if ($stripe_client){
                
                # retrieve the invoice from stripe
                my $stripe = Mojolicious::Plugin::Stripe::Client->new({
                    config => { secret_api_key => $stripe_client->{access_token} },
                });
                $stripe->invoices->retrieve( $delay->data('invoice_id'), $delay->begin, {
                    'expand[]' => ['customer','charge.card']
                } );
            }
        },
        sub {
            my ($delay, $stripe_client, $status, $invoice) = @_;
            $delay->pass($stripe_client, $status, $invoice);
            
            # use data in stripe client + invoice data
            # to determine which template to use
            # if invoice.charge.card.address_country eq 'Australia', template id = ...
            # else template id = ...
            
            if ($stripe_client){
                # get the template
                $self->db_templates->find_one(
                    { _id => bson_oid($stripe_client->{template_id}), deleted => bson_false }, $delay->begin
                );
            }
                
        },
        sub {
            my ($delay, $stripe_client, $status, $invoice, $template_doc) = @_;
            
            if ($stripe_client && $invoice && $status eq '200'){
                
                my $doc = {
                    owner => $stripe_client->{owner},
                    file => undef,
                    deleted => bson_false,
                    public => bson_false,
                    template_id => $stripe_client->{default_invoice_id}
                };

                my $source = $self->alloy->render($template_doc->{source}, $invoice);
                
                $self->db_documents->create($doc, sub{
                    my ($err, $doc) = @_;
                    $self->render(
                        data => $self->pdf_renderer(
                            $self->config->{media_directory}, 
                            $stripe_client->{owner},
                            $source
                        )
                    );
                });
                
            } else {
                
                $self->render( status => 404 );
            }
        }                
    );
    $delay->wait unless Mojo::IOLoop->is_running;

}


1;
