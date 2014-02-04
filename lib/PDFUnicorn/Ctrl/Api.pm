package PDFUnicorn::Ctrl::Api;
use Mojo::Base 'Mojolicious::Controller';

use Mango::BSON ':bson';
use Mojo::JSON;
use Try;

use lib '../PDF-Grid/lib';
use PDF::Grid;

#use Data::Dumper ('Dumper');

=item API

All calls to the API must include a Basic Authentication header containing your
API key.

    Authorisation: "Basic 1e551787-903e-11e2-b2b6-0bbccb145af3"
    
All calls to the API must use a secure (https) connection.

=cut


sub create {
	my $self = shift;
    my $data = $self->req->json();
    if (my $errors = $self->invalidate($self->item_schema, $data)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }
    
    warn 'create data: '.Data::Dumper->Dumper($data);

    $data->{owner} = $self->stash->{api_key_owner_id};
    $data->{deleted} = bson_false;
    $data->{public} = bson_false;
    delete $data->{id};
    delete $data->{_id};
    
    $self->render_later;
    $self->collection->create($data, sub{
        my ($err, $doc) = @_;
        $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
        $doc->{id} = delete $doc->{_id};
        $self->render(json => $doc);
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub find {
	my $self = shift;
    my $query = $self->req->query_params->to_hash;
    if (my $errors = $self->invalidate($self->query_schema, $query)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', errors => $errors }
        );
    }
    $query->{owner} = $self->stash->{api_key_owner_id};
    delete $query->{_id};
    delete $query->{id};
    
    $self->render_later;
        
    $self->collection->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        foreach my $doc (@$docs){
            $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
            $doc->{id} = delete $doc->{_id};
        }
        $self->render(json => { status => 'ok', data => $docs });
    }, {});
    
}

sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
    
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid($id), deleted => bson_false }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->stash->{api_key_owner_id}){
                $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
                $doc->{id} = delete $doc->{_id};    
                return $self->render(json => $doc) ;
            }
        }
        $self->render_not_found;
    });
}

#sub update{
#	my $self = shift;
#	my $id = $self->stash('id');
#    my $data = $self->req->json();
#    delete $data->{uri};
#
#    if (my $errors = $self->invalidate($self->item_schema, $data)){
#        return $self->render(
#            status => 422, json => { errors => $errors }
#        );
#    }
#
#    delete $data->{_id};
#    delete $data->{id};
#    
#    $data->{owner} = $self->stash->{api_key_owner_id};
#    
#    $self->render_later;
#    
#    $self->collection->update(
#        ( { _id => $id, owner => $self->$data->{owner} }, $data ) => sub {
#            my ($collection, $err, $doc) = @_;
#            if ($err){
#                warn $err;
#                $self->render_not_found;
#            } else {
#                $doc->{id} = delete $doc->{_id};
#                return $self->render(json => $doc);
#            }
#        }
#    );
#}

sub remove{
	my $self = shift;
	my $id = $self->stash('id');
	
    $self->render_later;
    
	$self->collection->find_one({ _id => bson_oid($id), deleted => bson_false }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->stash->{api_key_owner_id}){
                return $self->collection->remove($doc, sub{
                    my ($collection, $err, $mdoc) = @_;
                    if ($err){
                        return $self->render(
                            status => 500, json => { errors => [$err] }
                        );
                    }
                    return $self->render( status => 200, json => { 'ok' => 1 } );
                });
            }
        }
        $self->render_not_found;
    });
}


1;

