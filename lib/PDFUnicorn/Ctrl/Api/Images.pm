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
    my $id = $self->req->param('id');
    my $name = $self->req->param('name');
    my $filename = uri_escape($name);

    my $base = $self->app->media_directory.$self->api_key_owner;
    my $file = $base . "/$filename";
    
    if ($upload){
        make_path($base);
        $upload->move_to($file);
    } else {
        die Data::Dumper->Dumper($self->req);
    }
    
    
    $id ||= bson_oid;
    
    my $image_data = {
        name => $name,
        uri => "/api/v1/".$self->uri."/$id",
        id => $id,
        owner => $self->api_key_owner,
    };
    
    $self->render_later;
    
    $self->collection->create($image_data, sub{
        my ($err, $doc) = @_;
        #warn 'images api colletion create '.Data::Dumper->Dumper($doc);
        $self->render( 
            json => {
                status => 'ok',
                data => $doc
            }
        );
    });  
}


1;
