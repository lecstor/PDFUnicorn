package PDFUnicorn::Ctrl::Admin::Stripe::Invoices;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON ':bson';

use Mojo::UserAgent;
use Data::Dumper ('Dumper');


=header Connect to customer Stripe account

=cut

sub index{
    my $self = shift;
    $self->stash->{error} = undef;

    $self->stash->{stripe_client} = undef;
    
#    $self->render_later;
#        
#    $self->db_stripe_clients->find_one({ owner => $self->stash->{app_user}{_id} }, sub{
#        my ($err, $doc) = @_;
#        
#        $self->app->log->debug($doc || 'no doc');
#        
#        # stash the user's client doc if they are a stripe connect client
#        $self->stash->{stripe_client} = $doc;
#            
#        $self->render();
#    });
    
}

1;
