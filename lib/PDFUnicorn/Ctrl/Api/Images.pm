package PDFUnicorn::Ctrl::Api::Images;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use File::Path 'make_path';
use URI::Escape;


sub collection{ shift->db_images }

sub uri{ 'images' }
sub item_schema{ 'Image' }
sub query_schema{ 'ImageQuery' }


sub create {
	my $self = shift;
    my $upload = $self->req->upload('image');
    
    if (!$upload){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => 'There was no image data in the upload request.' } }
        );
    }
    
    #my $id = $self->req->param('id');
    my $src = $self->req->param('src') || $upload->filename;
    
    $src =~ s!^/+!!;
    $src =~ s!/+$!!;
    my $filename = uri_escape($src);

    my $image_data = {
        src => $src,
        owner => $self->stash->{api_key_owner_id},
    };
        
    $self->render_later;
    
    $self->collection->create($image_data, sub{
        my ($err, $doc) = @_;
        my $doc_id = $doc->{_id};
        my $base = $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id};
        my $file = $base . "/$filename";
        
        make_path($base);
        $upload->move_to($file);
        
        $self->serve_doc($doc);
    });  
}


sub find_one {
	my $self = shift;
	my $id = $self->stash('id');
    #return $self->render_not_found unless $id = $self->validate_type('oid', $id);
        
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid($id) }, sub{
        my ($err, $doc) = @_;
        if ($doc){
            warn "Found image";
            if ($doc->{owner} eq $self->stash->{api_key_owner_id}){
                return $self->serve_doc($doc);
            }
        }
        $self->render_not_found;
    });
}


sub serve_doc{
    my ($self, $doc) = @_;
	my $format = $self->stash('format');
    if ($format && $format eq 'binary'){
        my $media_base = $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id};
        $self->res->headers->content_disposition('attachment; filename='.$doc->{src}.';');
        my $local_file_name = $media_base.'/'.uri_escape($doc->{src});
        warn "image src: ".$doc->{src};
        my ($ext) = $doc->{src} =~ /\.([^.]+)$/;
        $self->res->headers->content_type("image/$ext");
        $self->res->content->asset(Mojo::Asset::File->new(path => $local_file_name));
        $self->rendered(200);
    } else {
        $doc->{uri} = "/v1/".$self->uri."/$doc->{_id}";
        $doc->{id} = delete $doc->{_id};
        $self->render(json => $doc ) ;
    }
}


1;

#    $self->render_file(
#        'filepath' => 'pdf_unicorn_demo1.pdf',
#        'format'   => 'pdf',                 # will change Content-Type "application/x-download" to "application/pdf"
#        'content_disposition' => 'inline',   # will change Content-Disposition from "attachment" to "inline"
#    );















