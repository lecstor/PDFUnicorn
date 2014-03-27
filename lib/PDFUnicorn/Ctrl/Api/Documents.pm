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
    POST /v1/documents.pdf
    { source: "<doc>Hello World!</doc>" }
Res:
    PDF file

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
            json => {
                type => 'invalid_request',
                message => 'Invalid parameters in request',
                errors => $errors
            }
        );
    }
    
	my $format = $self->stash('format');
	my $pdf = 1 if $format && $format eq 'pdf';
	
    $self->render_later;

    $data->{owner} = $self->stash->{api_key_owner_id};        
    $data->{file} = undef;
    $data->{deleted} = bson_false;
    $data->{public} = bson_false;
    delete $data->{id};
    delete $data->{_id};
    
    if ($pdf){
        # render PDF and return it in the response
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;

            my $delay = Mojo::IOLoop::Delay->new->data({ doc => $doc });

            $delay->steps(
                sub{
                    # get template if we have a template id and no doc source or template
                    my $delay = shift;
                    my $doc = $delay->data('doc');
                    
                    
                    if ($doc->{template_id} && !($doc->{source} || $doc->{template})){
                        $self->db_templates->find_one(
                            { _id => bson_oid($doc->{template_id}), deleted => bson_false }, $delay->begin
                        );
                    } else {
                        $delay->pass;
                    }
                },
                sub{
                    # render template and respond
                    my ($delay, $template_doc) = @_;
                    my $doc = $delay->data('doc');
                    
                    my $source = $doc->{source};
                    if (!$source){
                        my $template = $doc->{template} || $template_doc->{source};
                        $source = $self->alloy->render($template, $doc->{data}) if $template;
                    }
                    if (!$source){
                        my $error;
                        if ($doc->{template_id}){
                            $error = 'The requested document template was not found';
                        } else {
                            $error = 'The requested document source and template were empty';
                        }
                        $self->render(
                            status => 422,
                            json => {
                                type => 'invalid_request', message => "Invalid Request Error",
                                errors => [$error]
                            }
                        );
                    } else {                        
                        $self->render(
                            data => $self->pdf_renderer(
                                $self->config->{media_directory}, 
                                $self->stash->{api_key_owner_id},
                                $source
                            )
                        );
                    }
                }                
            );
        });
        
    } else {
        # respond with metadata then render PDF and store it

        $self->on(finish => sub{
            my $c = shift;
            my $delay = Mojo::IOLoop::Delay->new->data({
                doc => $c->stash->{'pdfunicorn.doc'}
            });
            
            $delay->steps(
                sub{
                    # get template if we have a template id and no doc source or template
                    my $delay = shift;
                    #my $doc = $c->stash->{'pdfunicorn.doc'};
                    my $doc = $delay->data('doc');
                    
                    if ($doc->{template_id} && !($doc->{source} || $doc->{template})){
                        $c->db_templates->find_one(
                            { _id => bson_oid($doc->{template_id}), deleted => bson_false }, $delay->begin
                        );
                    } else {
                        $delay->pass;
                    }
                },
                sub{
                    # render template and store file
                    my ($delay, $template_doc) = @_;
                    my $doc = $delay->data('doc');
                    
                    my $source = $doc->{source};
                    if (!$source){
                        my $template = $doc->{template} || $template_doc->{source};
                        $source = $self->alloy->render($template, $doc->{data}) if $template;
                    }
                    if (!$source){
                        my $error;
                        if ($doc->{template_id}){
                            $error = 'The requested document template was not found';
                        } else {
                            $error = 'The requested document source and template were empty';
                        }
                        $c->collection->set_render_error(
                            $doc->{_id}, 'invalid_request', "Invalid Request Error",
                            ['The requested document template was not found']
                        );
                    } else {                        
                        $c->pdf_grid_writer(
                            $c->stash->{api_key_owner_id}, $doc->{_id}, $doc->{name},
                            $c->pdf_renderer(
                                $c->config->{media_directory}, $c->stash->{api_key_owner_id},
                                $source
                            )
                        );
                    }
                }                
            );
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
	my $pdf = 1 if $format && $format eq 'pdf';
	
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid($id), deleted => bson_false }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->stash->{api_key_owner_id}){
                if ($pdf){
                    unless ($doc->{file}){
                        if (my $err = $doc->{render_error}){
                            return $self->render(
                                status => 422,
                                json => $err
                            );
                        } else {
                            $self->res->headers->header("Retry-after" => 1);
                            return $self->render(
                                status => 503,
                                json => {}
                            );
                        }
                    }
                    my $gfs = $self->gridfs->prefix($doc->{owner});
                    $self->res->headers->content_type('applicaion/pdf');
                    return $gfs->reader->open($doc->{file}, sub{
                        my ($reader, $err) = @_;
                        $self->render(data => $reader->slurp);
                    });
                } else {
                    $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
                    $doc->{id} = delete $doc->{_id};
                    delete $doc->{deleted};
                    delete $doc->{file};
                    delete $doc->{owner};
                    return $self->render(json => $doc );
                }
            }
        }
        $self->render_not_found;
    });
}

    

1;
