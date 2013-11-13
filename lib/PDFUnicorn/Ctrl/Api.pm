package PDFUnicorn::Ctrl::Api;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON ':bson';
use Mojo::JSON;
use Try;


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

    $self->render_later;
    $self->collection->create($data, sub{
        my ($err, $doc) = @_;
        $self->render(json => $doc);
    });
}

sub find {
	my $self = shift;
    my $query = $self->req->query_params->to_hash;
    $query = $self->auth_filters($query);
    try{
        $self->validate($self->query_schema, $query);
    } catch {
        return $self->render_exception($_);
    };
    my $rs = $self->collection->find($query);
    $self->render(json => $rs->all);
}

sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
    
    warn "ID: $id";
    
    $self->render_later;
    $self->collection->find_one({ id => $id }, sub{
        warn Data::Dumper->Dumper(\@_);
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->api_key){
                return $self->render(json => $doc) ;
            }
            if ($doc->{user} eq $self->auth_user->{_id}){
                return $self->render(json => $doc) ;
            }
            if ($doc->{public} && !$doc->{archived}){
                return $self->render(json => $doc);
            }
        }
        $self->render_not_found;
    });
}

sub update{
	my $self = shift;
	my $id = $self->stash('id');
    my $data = $self->req->json();
    delete $data->{_id};
    
    $self->render_later;
    $self->collection->find_one(bson_oid $id, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{user} eq $self->auth_user->{_id}){
                $data->{user} = $doc->{user};
                $self->validate($self->item_schema, $data);
                my $reply = $self->collection->update( { _id => bson_oid $id }, $data );
                return $self->render(json => { 'ok' => 1, data => $data, status => $reply });
            }
            
        }
        $self->render_not_found;
    });
}

sub archive{
	my $self = shift;
	my $id = $self->stash('id');
	$self->collection->find_one(bson_oid $id, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{user} eq $self->auth_user->{_id}){
                $doc->{archived} = bson_true;
                $self->collection->update({ _id => bson_oid $id }, $doc);
                return $self->render(json => { 'ok' => 1 });
            }
            
        }
        $self->render_not_found;
	});
}


1;

