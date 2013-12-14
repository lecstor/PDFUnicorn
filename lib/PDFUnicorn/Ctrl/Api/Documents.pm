package PDFUnicorn::Ctrl::Api::Documents;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use Mojo::IOLoop::Delay;

  
sub collection{ shift->db_documents }

sub uri{ 'documents' }
sub item_schema{ 'Document' }
sub query_schema{ 'DocumentQuery' }

sub create {
	my $self = shift;
    my $data = $self->req->json();
    if (my $errors = $self->invalidate($self->item_schema, $data)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }

    $data->{owner} = $self->api_key_owner;
    $data->{id} = $data->{id} ? "$data->{id}" : bson_oid;
    $data->{uri} = "/api/v1/".$self->uri."/$data->{id}";
    $data->{file} = undef;

    $self->render_later;
    
    if ($self->req->headers->accept && $self->req->headers->accept =~ m!\bapplication/pdf\b!){
        
        $self->collection->create($data, sub{
            my ($err, $doc) = @_;
            
            my $grid = PDF::Grid->new({
                media_directory => $self->app->media_directory.'/'.$self->api_key_owner.'/',
                source => $doc->{source},
            });
            
            $grid->render_template;
            my $pdf_doc = $grid->producer->stringify();    

            $self->render( data => $pdf_doc );
        });

        
    } else {
        
        $self->on(finish => sub{
            my $c = shift;
            
            my $doc = $self->stash->{'pdfunicorn.doc'};
            
            if (!$doc){ die "a flaming death.."; }
            
            my $grid = PDF::Grid->new({
                media_directory => $c->app->media_directory.'/'.$c->api_key_owner().'/',
                source => $doc->{source},
            });
            
            $grid->render_template;
            my $pdf_doc = $grid->producer->stringify();    
            $grid->producer->end;
            my $gfs = $self->gridfs->prefix($self->api_key_owner());
            my $oid = $gfs->writer->filename($doc->{name})->write($pdf_doc)->close;
            
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
            $self->stash->{'pdfunicorn.doc'} = $doc;
            $self->render(
                json => {
                    status => 'ok',
                    data => $doc
                }
            );
        });
        
    }


}


sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
    
    $self->render_later;
    $self->collection->find_one({ id => bson_oid $id }, sub{
        #warn Data::Dumper->Dumper(\@_);
        my ($err, $doc) = @_;
        if ($doc){
            if ($doc->{owner} eq $self->api_key_owner){
                my $accept_headers = $self->req->headers->accept;
                if ($accept_headers && $accept_headers =~ m!application/pdf!){
                    my $gfs = $self->gridfs->prefix($self->api_key_owner());
                    my $reader = $gfs->reader->open($doc->{file});
                    return $self->render(data => $reader->slurp);
                } else {
                    return $self->render(json => $doc);
                }
            }
        }
        $self->render_not_found;
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;  
}

    

1;
