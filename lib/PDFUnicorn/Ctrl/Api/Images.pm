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
    
    my $id = $self->req->param('id');
    my $name = $self->req->param('name');
    $name =~ s!^/+!!;
    $name =~ s!/+$!!;
    #my $filename = uri_escape($name);

    my $image_data = {
        name => $name,
        id => $id,
        owner => $self->api_key_owner,
    };
    
    $self->render_later;
    
    $self->collection->create($image_data, sub{
        my ($err, $doc) = @_;
        #warn 'images api colletion create '.Data::Dumper->Dumper($doc);
        my $doc_id = $doc->{_id};
        my $base = $self->app->media_directory.'/'.$self->api_key_owner;
        my $file = $base . "/$doc_id";
        
        make_path($base);
        $upload->move_to($file);
        
        $doc->{uri} = "/api/v1/".$self->uri."/$doc_id",
        $self->render( 
            json => {
                status => 'ok',
                data => $doc
            }
        );
    });  

}


1;
