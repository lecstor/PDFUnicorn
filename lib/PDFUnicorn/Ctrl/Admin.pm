package PDFUnicorn::Ctrl::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;
use JSON;

use Mango::BSON ':bson';

use Data::UUID;
use Mojo::JSON;
  
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

# TODO: argh! duplicated code from Ctrl::Admin::Rest::Apikeys::find
sub apikey {
	my $self = shift;
	my $user_id = $self->stash->{app_user}{_id};
	
	$self->stash->{password_set} = 1;
	
	unless($self->stash->{app_user}{password}){
	    $self->res->code(401);
	    return $self->render( error => 'no_password', keys => [] );
	}
	
    $self->render_later;
    
    my $query = { owner => bson_oid($user_id), deleted => bson_false };
    
    $self->db_apikeys->find_all($query, sub{
        my ($cursor, $err, $docs) = @_;
        my $json  = Mojo::JSON->new;
        if (@$docs){
            $self->render( keys => $json->encode($docs), error => '' );
        } else {
            $self->db_apikeys->create({
                owner => bson_oid($user_id),
                key => Data::UUID->new->create_str,
                name => 'the first one',
                active => bson_true,
                deleted => bson_false,
            }, sub {
                my ($err, $doc) = @_;
                $self->render( keys => $json->encode([$doc]), error => '' );
            });
        }
    }, { key => 1, owner => 1, _id => 0, name => 1, active => 1 });
}

sub billing {
	my $self = shift;
	$self->render();
}

sub personal {
	my $self = shift;
	$self->render();
}

sub api_docs {
    my $self = shift;
    $self->render();
}

sub markup_docs {
    my $self = shift;
    $self->render();
}

sub template_docs {
    my $self = shift;
    $self->render();
}

sub example {
    my $self = shift;
    $self->render();
}

sub set_password{
    my $self = shift;
    my $password = $self->param('password');
    my $app_user_id = $self->stash->{app_user}{_id};
    
    #return $self->status_code(401)->redirect_to('/log-in') unless $app_user_id;
    $self->render_later;
    $self->db_users->set_password(
        $app_user_id, $password,
        $self->random_string(length => 2),
        sub{ $self->redirect_to('/admin') },
    );
    
}

sub get_pdf{
	my $self = shift;
	my $source = $self->param('source');

    my $grid = PDF::Grid->new({
        #media_directory => $self->config->{media_directory}.'/'.$self->stash->{api_key_owner_id}.'/',
        source => $source,
    });
    
    $grid->render;
    my $pdf_doc = $grid->producer->stringify();    
    $grid->producer->end;
            
    $self->res->headers->content_type("application/pdf");
    $self->res->headers->content_disposition('inline; filename=pdfunicorn.com-test.pdf;');
    $self->render( data => $pdf_doc );
}

sub preview{
    my $self = shift;
    my $data_json = $self->param('data');
    my $template = $self->param('template');

    my $data = eval{ decode_json($data_json) };
    if (my $err = $@){
        warn $err->message;
        warn $data_json;
        my $message = $err->message;
        $message =~ s/\s+at [\w_\-\/.]+PDFUnicorn.*//;
        return $self->render(
            template => 'root/demo_form',
            error => 'Data Error: '.$message,
            time => time
        );
    }

    my $source = eval{ $self->alloy->render($template, $data) };
    if (my $err = $@){
        # Template::Exception
        #warn $err->as_string;
        #warn $data_json;
        my $message;
        eval{ $message = $err->as_string; };
        if ($@){
            $message = $err->to_string;
        }
        $message =~ s/.*\s\-\s//;
        return $self->render(
            template => 'root/demo_form',
            error => 'Template Error: '.$message,
            time => time
        );
    }
    
    my $grid = PDF::Grid->new({
        media_directory => $self->config->{media_directory}.'/'. $self->stash->{account_id},
        source => $source,
    });
    
    eval{ $grid->render };
    if (my $err = $@){
        warn $err->message;
        warn $data_json;
        my $message = $err->message;
        $message =~ s/\s+at \/.*//;
        return $self->render(
            template => 'root/demo_form',
            error => $message,
            time => time
        );
    }

    my $pdf_doc = $grid->producer->stringify();    
    $grid->producer->end;
            
    $self->res->headers->content_type("application/pdf");
    $self->res->headers->content_disposition('inline; filename=pdfunicorn.com-tryit.pdf;');
    $self->render( data => $pdf_doc );
}

1;
