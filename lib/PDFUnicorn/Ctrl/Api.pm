package PDFUnicorn::Ctrl::Api;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON ':bson';
use Mojo::JSON;
use Try;

use lib '../PDF-Grid/lib';
use PDF::Grid;

#use Data::Dumper ('Dumper');

sub auth_filters {
	my ($self, $query) = @_;
    #warn 'auth_filters query: '.$self->dumper($query);
	if (exists $query->{archived} && $query->{archived}){
	    $query->{user} = 1;
	}
	if (exists $query->{user}){
	    if ($query->{user}){
	        #warn 'auth_filters:auth_user_id: '.$self->auth_user_id;
	        $query->{user} = $self->auth_user_id;
	    } else {
	        delete $query->{user};
	    }
	}
	unless (exists $query->{user} && $query->{user}){
	    $query->{public} = bson_true;
	}
	return $query;
}

sub create {
	my $self = shift;
    #warn Mojo::JSON->new->encode($self->req->json());
    my $data = $self->req->json();
    $self->validate($self->item_schema, $data);

    $data->{owner} = $self->api_key;
    $data->{id} = "$data->{id}";
    $data->{uri} = "/v1/".$self->uri."/$data->{id}";
    
    $self->render_later;
    $self->collection->create($data, sub{
        my ($err, $doc) = @_;
        $self->render(json => $doc);
    });
    
}

sub find {
	my $self = shift;
    my $query = $self->req->query_params->to_hash;
    try{
        $self->validate($self->query_schema, $query);
    } catch {
        return $self->render_exception($_);
    };
    $query->{owner} = $self->api_key_owner;
    $self->render_later;
    $self->collection->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        $self->render(json => $docs);
    });
}

sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
    
    $self->render_later;
    $self->collection->find_one({ id => $id }, sub{
        #warn Data::Dumper->Dumper(\@_);
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->api_key_owner){
                return $self->render(json => $doc) ;
            }
        }
        $self->render_not_found;
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;  
}

sub update{
	my $self = shift;
	my $id = $self->stash('id');
    my $data = $self->req->json();
    $self->validate($self->item_schema, $data);
    delete $data->{_id};
    $data->{owner} = $self->api_key_owner;
    $self->render_later;
    $self->collection->update(
        ( { _id => $id, owner => $self->api_key_owner }, $data ) => sub {
            my ($collection, $err, $doc) = @_;
            if ($err){
                warn $err;
                $self->render_not_found;
            } else {
                return $self->render(json => { 'ok' => 1, data => $doc });
            }
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub archive{
	my $self = shift;
	my $id = $self->stash('id');
	$self->collection->find_one(bson_oid $id, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->api_key_owner){
                $doc->{archived} = bson_true;
                # TODO: needs to be non-blocking..
                $self->collection->update({ _id => bson_oid $id }, $doc);
                return $self->render(json => { 'ok' => 1 });
            }
            
        }
        $self->render_not_found;
	});
}


1;

