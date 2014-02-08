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
                message => "Invalid Request Error",
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
    
    my $pdf_renderer = $self->stash->{pdf_renderer} = sub{
        my ($self, $source) = @_;
        my $grid = PDF::Grid->new({
            media_directory => $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id}.'/',
            source => $source,
        });
        $grid->render;
        my $pdf_doc = $grid->producer->stringify();    
        $grid->producer->end;
        return $pdf_doc;              
    };

    my $delayed_find_one = $self->stash->{delayed_find_one} = sub{
        my $delay = shift;
        my $id = $self->stash->{'pdfunicorn.doc'}{template_id};
        $self->db_templates->find_one(
            { _id => bson_oid($id), deleted => bson_false },
            $delay->begin
        );
    };

    if ($pdf){
        # render PDF and return it in the response
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            
            if ($doc->{source} || $doc->{template}){
                my $source = $doc->{source};
                if ($doc->{template}){
                    $source = $self->alloy->render($doc->{template}, $doc->{data} || {});
                }
                $self->render( data => $pdf_renderer->($self, $source) );
            } elsif ($doc->{template_id}){                
                # stash doc to keep it in scope
                $self->stash->{'pdfunicorn.doc'} = $doc;

                my $delay = Mojo::IOLoop::Delay->new;
                $delay->steps(
                    $delayed_find_one,
                    sub {
                        my ($delay, $template) = @_;
                        if ($template){
                            my $source = $self->alloy->render($template->{source}, $self->stash->{'pdfunicorn.doc'}{data} || {});
                            $self->render( data => $self->stash->{pdf_renderer}->($self, $source) );
                        } else {
                            $self->render(
                                status => 422,
                                json => {
                                    type => 'invalid_request',
                                    message => "Invalid Request Error",
                                    errors => ['The requested document template was not found']
                                }
                            );
                        }
                    }
                );
                $delay->wait unless Mojo::IOLoop->is_running;
            }
        });
        
    } else {
        # respond with metadata then render PDF and store it
        $self->on(finish => sub{
            my $c = shift;

            my $pdf_writer = $c->stash->{pdf_writer} = sub{
                my ($self, $doc, $pdf_doc) = @_;
                
                my $gfs_writer = $self->gridfs->prefix($self->stash->{api_key_owner_id})->writer;
                
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
                        $self->collection->find_and_modify($opts => sub {
                            my ($collection, $err, $doc) = @_;
                            # anything to do here?
                            # call a webhook?
                        });
                    });
                });
            };
            
            my $doc = $c->stash->{'pdfunicorn.doc'};

            if ($doc->{source} || $doc->{template}){
                my $source = $doc->{source};
                if ($doc->{template}){
                    $source = $c->alloy->render($doc->{template}, $doc->{data} || {});
                }
                $pdf_writer->($c, $doc, $pdf_renderer->($self, $source));
            } elsif ($doc->{template_id}){                
                my $delay = Mojo::IOLoop::Delay->new;
                $delay->steps(
                    $c->stash->{delayed_find_one},
                    sub {
                        my ($delay, $template) = @_;
                        if ($template){
                            my $source = $c->alloy->render($template->{source}, $c->stash->{'pdfunicorn.doc'}{data} || {});
                            #$c->render( data => $c->stash->{pdf_renderer}->($c, $source) );
                            $c->stash->{pdf_writer}->(
                                $c,
                                $c->stash->{'pdfunicorn.doc'},
                                $c->stash->{pdf_renderer}->($c, $source)
                            );
                        } else {
                            # here we set an error in the document
                            my $opts = {
                                query => { _id => $c->stash->{'pdfunicorn.doc'}->{_id} },
                                update => {
                                    '$set' => {
                                        render_error => {
                                            type => 'invalid_request',
                                            message => "Invalid Request Error",
                                            errors => ['The requested document template was not found']
                                        }
                                    }
                                },
                            };
                            $self->collection->find_and_modify($opts => sub {
                                my ($collection, $err, $doc) = @_;
                                # anything to do here?
                                # call a webhook?
                            });
                        }
                    }
                );
                $delay->wait unless Mojo::IOLoop->is_running;
            }            
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
