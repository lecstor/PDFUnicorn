package PDFUnicorn::Ctrl::Api::Images;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use File::Path 'make_path';
use URI::Escape;


sub collection{ shift->db_images }

sub uri{ 'images' }
#sub item_schema{ 'Image' }
sub query_schema{ 'ImageQuery' }


sub create {
	my $self = shift;
    my $upload = $self->req->upload('file');
    
    # 'image" deprecated, use "file"
    $upload = $self->req->upload('image') unless $upload;
    
    if (!$upload){
        return $self->render(
            status => 422,
            json => { type => 'invalid_request', errors => ['There was no file data in the upload request.'] }
        );
    }
    
    my $stock = $self->req->param('stock');
    my $src = $self->req->param('src');
    $src = $upload->filename unless $src;
    
    $src =~ s!^/+!!;
    $src =~ s!/+$!!;
    my $filename = uri_escape($src);

    my $image_data = {
        src => $src,
        owner => $self->stash->{api_key_owner_id},
        stock => $stock ? bson_true : bson_false,
        deleted => bson_false,
        public => bson_false,
    };

#    if (my $errors = $self->invalidate($self->item_schema, $image_data)){
#        return $self->render(
#            status => 422,
#            json => { type => 'invalid_request', errors => $errors }
#        );
#    }
        
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
    return $self->render_not_found unless $id = $self->validate_type('oid', $id);
        
    $self->render_later;
    $self->collection->find_one({ _id => bson_oid($id), deleted => bson_false }, sub{
        my ($err, $doc) = @_;
        if ($doc){
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
    if ($format && $format eq 'img'){
        my $media_base = $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id};
        $self->res->headers->content_disposition('attachment; filename='.$doc->{src}.';');
        my $local_file_name = $media_base.'/'.uri_escape($doc->{src});
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















