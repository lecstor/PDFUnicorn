package PDFUnicorn::Ctrl::Admin::Rest::Apikeys;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;

use Mango::BSON ':bson';
use Data::UUID;
use Try;


sub set_active {
	my $self = shift;
	
	my $data = $self->req->json();
	
    $self->render_later;

	$self->db_apikeys->update(
	   { key => $self->stash->{'key'}, owner => $self->stash->{app_user}{_id} },
	   { '$set' => { active => $data->{active} } },
	   sub {
	       my ($err, $doc) = @_;
	       $self->render(json => { status => 'ok' });
	   }
	);
}

sub delete{
    my $self = shift;
    my $data = $self->req->json();
    
    $self->render_later;

    $self->db_apikeys->update(
       { key => $self->stash->{'key'}, owner => $self->stash->{app_user}{_id} },
       { '$set' => { trashed => bson_true, active => bson_false } },
       sub {
           my ($err, $doc) = @_;
           $self->render(json => { status => 'ok' });
       }
    );
}

# TODO: argh! duplicated code from Ctrl::Admin::apikey
sub find{
    my ($self) = shift;
    my $user_id = $self->app_user_id;
    
	unless($self->stash->{app_user}{password}){
	    $self->res->code(401);
	    return $self->render( json => { error => 'no_password' } );
	}
	
    $self->render_later;
    
    my $query = { owner => $user_id, trashed => bson_false };
    
    $self->db_apikeys->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        my $json  = Mojo::JSON->new;
        if ($docs && @$docs){
            $self->render( json => { status => 'ok', data => $docs } );
        } else {
            $self->db_apikeys->create({
                owner => $user_id,
                key => Data::UUID->new->create_str,
                name => 'the first one',
                active => bson_true,
                trashed => bson_false,
            }, sub {
                my ($err, $doc) = @_;
                $self->render( json => { status => 'ok', data => [$doc] } );
            });
        }
    }, { key => 1, owner => 1, _id => 0, name => 1, active => 1 });
    
}

1;
