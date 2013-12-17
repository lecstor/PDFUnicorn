package PDFUnicorn::Ctrl::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;

use Mango::BSON ':bson';

use Data::UUID;

use Try;

use lib '../PDF-Grid/lib';
use PDF::Grid;

# Render template "admin/dash.html.ep"
sub dash {
	my $self = shift;
	if (exists $self->req->params->to_hash->{'get-started'}){
	    return $self->render(template => 'admin/get_started');
	}
	$self->render();
}

sub apikey {
	my $self = shift;
	my $user = $self->app_user;
	
    $self->render_later;
    
    my $query = { owner => $user->{_id} };
    $self->db_apikeys->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        if (@$docs){
            $self->render( keys => $docs );
        } else {
            $self->db_apikeys->create({
                owner => $user->{_id},
                key => Data::UUID->new->create_str,
                name => 'the first one',
                active => bson_true,
            }, sub {
                my ($err, $docs) = @_;
                $docs ||= [];
                $self->render( keys => $docs);
            });
        }
    }, { key: 1, owner: 1, _id:0 });
}

sub billing {
	my $self = shift;
	$self->render();
}

sub personal {
	my $self = shift;
	$self->render();
}


sub get_pdf{
	my $self = shift;
	my $source = $self->param('source');

    my $grid = PDF::Grid->new({
        #media_directory => $self->app->media_directory.'/'.$self->api_key_owner().'/',
        source => $source,
    });
    
    $grid->render_template;
    my $pdf_doc = $grid->producer->stringify();    
    $grid->producer->end;
            
    $self->res->headers->content_type("application/pdf");
    $self->res->headers->content_disposition('inline; filename=pdfunicorn.com-test.pdf;');
    $self->render( data => $pdf_doc );
}

1;
