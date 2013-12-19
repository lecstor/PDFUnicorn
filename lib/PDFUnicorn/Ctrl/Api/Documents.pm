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
    POST /api/v1/documents.binary
    { source: "<doc>Hello World!</doc>" }
Res:
    Binary file

Req:
    POST /api/v1/documents
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
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }

	my $format = $self->stash('format');
	my $binary = 1 if $format && $format eq 'binary';
	
    $self->render_later;

    $data->{owner} = $self->stash->{api_key_owner}{_id};        
    $data->{file} = undef;
    $data->{id} = "$data->{id}" if $data->{id};
        
    if ($binary){
        
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            
            my $grid = PDF::Grid->new({
                media_directory => $self->app->media_directory.'/'.$self->stash->{api_key_owner}{_id}.'/',
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
                media_directory => $c->app->media_directory.'/'.$c->stash->{api_key_owner}{_id}.'/',
                source => $doc->{source},
            });
            
            $grid->render_template;
            my $pdf_doc = $grid->producer->stringify();    
            $grid->producer->end;
            my $gfs = $c->gridfs->prefix($c->stash->{api_key_owner}{_id});
            my $oid = $gfs->writer->filename($doc->{name})->write($pdf_doc)->close;
            
            # here we set the file oid in the document
            my $opts = {
                query => { id => $doc->{id} },
                update => { '$set' => { file => $oid }},
            };
            $self->collection->find_and_modify($opts => sub {
                my ($collection, $err, $doc) = @_;
                # anything to do here?
                # call a webhook?
            });
        });
    
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            warn $err if $err;
            $doc->{uri} = "/api/v1/".$self->uri."/$doc->{_id}";
            $self->stash->{'pdfunicorn.doc'} = $doc;
            $self->render( json => { status => 'ok', data => $doc } );
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
    $self->collection->find_one({ _id => bson_oid $id }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->stash->{api_key_owner}{_id}){
                if ($binary){
                    my $gfs = $self->gridfs->prefix($doc->{owner});
                    my $reader = $gfs->reader->open($doc->{file});
                    return $self->render(data => $reader->slurp);
                } else {
                    $doc->{uri} = "/api/v1/".$self->uri."/$doc->{_id}";
                    return $self->render(json => { status => 'ok', data => $doc });
                }
            }
        }
        $self->render_not_found;
    });
}

    

1;
