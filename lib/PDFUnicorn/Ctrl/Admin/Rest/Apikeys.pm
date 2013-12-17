package PDFUnicorn::Ctrl::Admin::Rest::Apikeys;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;

use Mango::BSON ':bson';

use Try;


sub set_active {
	my $self = shift;
	
	my $data = $self->req->json();
	
    $self->render_later;

	$self->db_apikeys->update(
	   { key => $self->stash->{'key'}, owner => bson_oid $self->app_user_id },
	   {
	       '$set' => {
	           key => $self->stash->{'key'},
	           owner => $self->api_key_owner,
	           active => $data->{active},
	       }
	   }, sub {
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
       { key => $self->stash->{'key'}, owner => bson_oid $self->app_user_id },
       {
           '$set' => {
               key => $self->stash->{'key'},
               owner => $self->api_key_owner,
               active => bson_false,
               trashed => bson_true,
           }
       }, sub {
           my ($err, $doc) = @_;
           $self->render(json => { status => 'ok' });
       }
    );
}


1;
