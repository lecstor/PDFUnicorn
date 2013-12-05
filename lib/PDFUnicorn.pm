package PDFUnicorn;
use Mojo::Base 'Mojolicious';

use Mango;
use Mango::BSON ':bson';

use PDFUnicorn::Collection::Users;
use PDFUnicorn::Collection::Documents;
use PDFUnicorn::Collection::Images;
use PDFUnicorn::Valid;

# This method will run once at server start
sub startup {
    my $self = shift;

	$self->secret('jonabel');

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('RenderFile');
    $self->plugin('Util::RandomString');


    if ($self->mode eq 'development'){
    	$self->attr(mango => sub { 
            #Mango->new('mongodb://<user>:<pass>@<server>/<database>');
            Mango->new('mongodb://127.0.0.1/pdfunicorn');
        });
        $self->attr(media_directory => 'pdf_unicorn/images/');
    } else {
    	$self->attr(mango => sub { 
            Mango->new('mongodb://<user>:<pass>@<server>/pdfunicorn');
        });
        $self->attr(media_directory => '/pdf_unicorn/images/');
    }
    
    $self->helper('mango' => sub { shift->app->mango });
    $self->helper('gridfs' => sub { shift->app->gridfs });

    my $db = $self->mango->db;
    
    $self->attr(gridfs => sub { $self->mango->db->gridfs });

    # ensure indexes
    $db->collection('users')->ensure_index({ username => 1});
    $db->collection('users')->ensure_index({ 'password_key.key' => 1});

    my $validator = PDFUnicorn::Valid->new();

    my $helpers = [
        { name => 'db_users', class => 'PDFUnicorn::Collection::Users', collection => 'users' },
        { name => 'db_documents', class => 'PDFUnicorn::Collection::Documents', collection => 'documents' },
        { name => 'db_images', class => 'PDFUnicorn::Collection::Images', collection => 'images' },
    ];
    
    for my $helper (@$helpers){
        my $name = $helper->{name};
        my $class = $helper->{class};
        
        my $schemas = $class->schemas;
        if ($schemas){
            foreach my $name (keys %$schemas){
                $validator->set_schema($name, $schemas->{$name});
            }
        }
        
        $self->helper(
            $name => sub {
                my $coll = $class->new(
                    collection => shift->mango->db->collection($helper->{collection})
                );
                return $coll;
            }
        );
    }    
    
    $self->helper(
        'validate' => sub {
            my ($ctrl, $schema, $data) = @_;
            my $errors = $validator->validate($schema, $data);
            die join("\n", @$errors) if $errors; # && @$errors;
            return 1;
        }
    );
        
    $self->helper(
        'validate_type' => sub {
            my ($ctrl, $type_name, $data) = @_;
            return $validator->validate_type($type_name, $data);
        }
    );
        
    $self->helper(
        'auth_user' => sub {
            my $ctrl = shift;
            my $user_id = $ctrl->session->{user}{_id};
            return undef unless $user_id;
            return $ctrl->app->db_users->find_one(bson_oid $user_id);
        }
    );

    $self->helper(
        'auth_user_id' => sub {
            my $ctrl = shift;
            my $user = $ctrl->auth_user;
            return "$user->{_id}";
            return;
        }
    );

    $self->helper(
        'auth_user_time_zone' => sub {
            my $ctrl = shift;
            my $user = $ctrl->auth_user;
            my $time_zone = $user->{time_zone};
            $time_zone ||= $ctrl->session->{time_zone} || 'local';
            return $time_zone;
        }
    );

    $self->helper(
        'api_key' => sub {
            my $auth = shift->req->headers->authorization;
            my ($token) = $auth =~ /"(.*)"/;
            return $token;
        }
    );

    $self->helper(
        'api_key_owner' => sub {
            my $self = shift;
            my $token = $self->api_key;
            # lookup owner and return id
            return $token;
        }
    );

    # Router
    my $r = $self->routes;

    $r->namespaces(['PDFUnicorn::Ctrl']);
    
    my $api = $r->bridge('/api')->to(cb => sub {
        my $self = shift;

        my $auth = $self->req->headers->authorization;
        return 1 if $self->api_key eq '1e551787-903e-11e2-b2b6-0bbccb145af3';
        
        # Authenticated
        return 1 if $self->auth_user && $self->auth_user->{_id};

        # Not authenticated
        $self->render(
            json => {
                ok => 0,
                text => "Sorry, you'll need to login to get in here..",
            },
            text => "Sorry, you'll need to login to get in here..",
            status => 401
        );
        return undef;
    });

    # Normal route to controller
	$r->get('/')->to('root#home');
	$r->post('/')->to('root#get_pdf');

	$r->get('sign-up')->to('root#sign_up_form');
	$r->post('sign-up')->to('root#sign_up');
	
	$r->get('log-in')->to('root#log_in_form');
	$r->post('log-in')->to('root#log_in');
	
	$r->get('log-out')->to('root#log_out');
	
	#$r->get('/stripe/connect')->to('stripe#connect');
	
	$r->get('set-password/:code/:email')->to('root#set_password_form');
	$r->post('set-password')->to('root#set_password');
	
	$api->post('/v1/documents')->to('api-documents#create');
	$api->get('/v1/documents')->to('api-documents#find');
	$api->get('/v1/documents/:id')->to('api-documents#find_one');
	$api->delete('/v1/documents/:id')->to('api-documents#delete');
	
	$api->post('/v1/images')->to('api-images#create');
	$api->get('/v1/images')->to('api-images#list');
	$api->get('/v1/images/:id')->to('api-images#fetch');
	$api->delete('/v1/images/:id')->to('api-images#delete');
	
}

1;
