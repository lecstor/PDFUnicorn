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
    if (my $errors = $self->invalidate($self->item_schema, $data)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }

    $data->{owner} = $self->api_key;
    $data->{id} = "$data->{id}";
    
    $self->render_later;
    $self->collection->create($data, sub{
        my ($err, $doc) = @_;
        $doc->{uri} = "/api/v1/".$self->uri."/$doc->{_id}";
        $self->render(json => { status => 'ok', data => $doc });
    });
    
}

sub find {
	my $self = shift;
    my $query = $self->req->query_params->to_hash;
    if (my $errors = $self->invalidate($self->query_schema, $query)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }
    $query->{owner} = $self->api_key_owner;
    $self->render_later;
    $self->collection->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        foreach my $doc (@$docs){
            $doc->{uri} = "/api/v1/".$self->uri."/$doc->{_id}";
        }
        $self->render(json => { status => 'ok', data => $docs });
    });
}

sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
    
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid $id }, sub{
        #warn Data::Dumper->Dumper(\@_);
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->api_key_owner){
                $doc->{uri} = "/api/v1/".$self->uri."/$doc->{_id}";
                return $self->render(json => { status => 'ok', data => $doc }) ;
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
    delete $data->{uri};

    if (my $errors = $self->invalidate($self->item_schema, $data)){
        return $self->render(
            status => 422, json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }

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
                return $self->render(json => { status => 'ok' });
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
                return $self->render(json => { status => 'ok' });
            }
            
        }
        $self->render_not_found;
	});
}


1;

