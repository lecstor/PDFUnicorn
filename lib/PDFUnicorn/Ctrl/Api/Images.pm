package PDFUnicorn::Ctrl::Api::Images;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;

sub collection{ shift->db_images }

sub uri{ 'images' }
sub item_schema{ 'Image' }
sub query_schema{ 'ImageQuery' }


sub create {
	my $self = shift;
    my $upload = $self->req->upload;
    my $name = $self->req->params->{'name'};
    my $base = $self->app->media_directory.'/'.$self->api_key_owner;
    my $file = $base . '/$name';
    $upload->move_to($file);

}


1;
