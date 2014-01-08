package PDFUnicorn::Ctrl::Api::Documents;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use Mojo::IOLoop;

sub collection{ shift->db_documents }

sub uri{ 'documents' }
sub item_schema{ 'Document' }
sub query_schema{ 'DocumentQuery' }


=item API: Document Create

Create a document. Returns the generated document by default.
Returns document metadata if meta format is specified.

May optionally include your internal id for the document.

Req:
    POST /v1/documents.binary
    { source: "<doc>Hello World!</doc>" }
Res:
    Binary file

Req:
    POST /v1/documents
    { source: "<doc>Hello World!</doc>", id: "mydocid" }
Res:
    JSON: {
        source: "<doc>Hello World!</doc>",
        id: "mydocid",
        _id: "blahblah",
    }

=cut

sub create {
	my $self = shift;
    my $data = $self->req->json();
    if (my $errors = $self->invalidate($self->item_schema, $data)){
        return $self->render(
            status => 422,
            json => { object => 'invalid_request', errors => $errors }
        );
    }

	my $format = $self->stash('format');
	my $binary = 1 if $format && $format eq 'binary';
	
    $self->render_later;

    $data->{owner} = $self->stash->{api_key_owner_id};        
    $data->{file} = undef;
    #$data->{id} = "$data->{id}" if $data->{id};
    delete $data->{id};
    delete $data->{_id};
    
    if ($binary){
        
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            
            my $grid = PDF::Grid->new({
                media_directory => $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id}.'/',
                source => $doc->{source},
            });
            
            $grid->render_template;
            my $pdf_doc = $grid->producer->stringify();    
            $grid->producer->end;

            $self->render( data => $pdf_doc );
        });
        
    } else {
        
        $self->on(finish => sub{
            my $c = shift;
            
            my $doc = $c->stash->{'pdfunicorn.doc'};
                        
            if (!$doc){ die "a flaming death.."; }
                        
            my $grid = PDF::Grid->new({
                media_directory => $c->config->{media_directory}.'/'.$c->stash->{api_key_owner_id}.'/',
                source => $doc->{source},
            });
            
            $grid->render_template;
            my $pdf_doc = $grid->producer->stringify();    
            $grid->producer->end;
                        
            my $gfs_writer = $c->gridfs->prefix($c->stash->{api_key_owner_id})->writer;
            
            $gfs_writer->filename($doc->{name});
            $gfs_writer->content_type('application/pdf');
            $gfs_writer->write($pdf_doc, sub{
                my ($wwriter, $err) = @_;
                warn "!!! $err" if $err;
                # TODO: check err
                
                $wwriter->close(sub{
                    my ($cwriter, $err, $oid) = @_;
                    # TODO: check err
                    warn "!!! $err" if $err;
                    
                    # here we set the file oid in the document
                    my $opts = {
                        query => { _id => $doc->{_id} },
                        update => { '$set' => { file => $oid }},
                    };
                    $c->collection->find_and_modify($opts => sub {
                        my ($collection, $err, $doc) = @_;
                        # anything to do here?
                        # call a webhook?
                    });
                });
                Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
            });
            Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
            
            return;
        });
    
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
            $self->stash->{'pdfunicorn.doc'} = $doc;
            my $tmp_doc = {%$doc};
            $tmp_doc->{id} = delete $tmp_doc->{_id};
            $self->render( json => $tmp_doc );
        });
    }

}


sub find_one {
	my $self = shift;	
	my $id = $self->stash('id');
    return $self->render_not_found unless $id = $self->validate_type('oid', $id);
	my $format = $self->stash('format');
	my $binary = 1 if $format && $format eq 'binary';
	
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid($id) }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->stash->{api_key_owner_id}){
                if ($binary){
                    my $gfs = $self->gridfs->prefix($doc->{owner});
                    $self->res->headers->content_type('applicaion/pdf');
                    return $gfs->reader->open($doc->{file}, sub{
                        my ($reader, $err) = @_;
                        $self->render(data => $reader->slurp);
                    });
                } else {
                    $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
                    $doc->{id} = delete $doc->{_id};
                    return $self->render(json => $doc );
                }
            }
        }
        $self->render_not_found;
    });
}

    

1;
