package PDFUnicorn::Ctrl::Admin::Stripe::Customer;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;

use Mango::BSON ':bson';
use Data::UUID;
use Try;


sub find{
    my ($self) = shift;
    my $user = $self->stash->{app_user};
    
    $self->render_later;
    
    $self->stripe->customers->retrieve(
        $user->{stripe_id},
        sub{
            my ($client, $data) = @_;
            # TODO: didn't see an error with broken code.. $self->render( json => $data->subscription );
            $self->render( json => $data );
        }
    );
}

1;
