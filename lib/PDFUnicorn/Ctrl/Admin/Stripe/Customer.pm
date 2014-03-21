package PDFUnicorn::Ctrl::Admin::Stripe::Customer;
use Mojo::Base 'Mojolicious::Controller';

=header AJAX Backend for billing page

=cut

sub find{
    my ($self) = shift;
    my $user = $self->stash->{app_user};
    
    $self->render_later;
    
    $self->stripe->customers->retrieve(
        $user->{stripe_id},
        #{ 'expand[]' => 'default_card' }, # doesn't work
        sub{
            my ($client, $status, $data) = @_;
            # TODO: didn't see an error with broken code.. $self->render( json => $data->subscription );
            $self->render( json => $data );
        }
    );
}


sub update{
    my ($self) = shift;
    my $user = $self->stash->{app_user};
    
    my $data = $self->req->json();
    my $card = $data->{'card'};
    
    if ($card){
        $self->render_later;
    
        $self->stripe->customers->update(
            $user->{stripe_id},
            { card => $card, 'expand[]' => 'default_card' },
            sub{
                my ($client, $status, $data) = @_;
                # TODO: didn't see an error with broken code.. $self->render( json => $data->subscription );
                $self->render( json => $data );
            }
        );
    } else {
        $self->render( json => { error => 'no updatable params' } );
    }
    
    
}


1;
