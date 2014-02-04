package PDFUnicorn;
use Mojo::Base 'Mojolicious';

use Mango;
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);
use Mojo::IOLoop;

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;

use PDFUnicorn::Collection::Users;
use PDFUnicorn::Collection::Documents;
use PDFUnicorn::Collection::Templates;
use PDFUnicorn::Collection::Images;
use PDFUnicorn::Collection::APIKeys;
use PDFUnicorn::Valid;
use PDFUnicorn::Template::Alloy;

use Try;

use lib '../Mojolicious-Plugin-Stripe/lib';

## Forward error messages to the application log
#Mojo::IOLoop->singleton->reactor->on(error => sub {
#  my ($reactor, $err) = @_;
#  app->log->error($err);
#});

# This method will run once at server start
sub startup {
    my $self = shift;

	$self->secrets(['jonabel']);

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('RenderFile');
    $self->plugin('Util::RandomString');
    $self->plugin('Config');
    $self->plugin('Stripe');

    warn "Mode: ".$self->mode;

    # add empty app_user to stash so templates can check it
    $self->defaults->{app_user} = undef;

    $self->attr(mango => sub { 
        Mango->new($self->config->{mongodb}{connect});
    });
    
    $self->helper('mango' => sub { shift->app->mango });
    $self->helper('gridfs' => sub { shift->app->gridfs });

    $self->attr(alloy => sub { PDFUnicorn::Template::Alloy->new });
    $self->helper('alloy' => sub { shift->app->alloy });
    
    # Wait for all operations to have reached at least 1 server
    my $wait = $self->mango->w;

    my $db = $self->mango->db;
    
    $self->attr(gridfs => sub { $self->mango->db->gridfs });

    # ensure indexes
    
    # db.fs.chunks.ensureIndex({files_id:1, n:1}, {unique: true});
    
    # this breaks api_documents.t
    #$self->gridfs->chunks->ensure_index({ files_id => 1, n => 1 }, { unique => 1 });
    
    $db->collection('users')->ensure_index({ email => 1}, { unique => 1 });
    $db->collection('users')->ensure_index({ 'password_key.key' => 1});
    
    # use bson_doc to maintain order of attributes    
    $db->collection('apikeys')->ensure_index(
        bson_doc(
            key => 1,
            owner => 1,
            deleted => 1,
            name => 1,
            active => 1
        )
    );

    my $validator = PDFUnicorn::Valid->new();

    my $helpers = [
        { name => 'db_users', class => 'PDFUnicorn::Collection::Users', collection => 'users' },
        { name => 'db_documents', class => 'PDFUnicorn::Collection::Documents', collection => 'documents' },
        { name => 'db_templates', class => 'PDFUnicorn::Collection::Templates', collection => 'templates' },
        { name => 'db_images', class => 'PDFUnicorn::Collection::Images', collection => 'images' },
        { name => 'db_apikeys', class => 'PDFUnicorn::Collection::APIKeys', collection => 'apikeys' },
    ];
    
    for my $helper (@$helpers){
        my $name = $helper->{name};
        my $class = $helper->{class};
        
        my $schemas = $class->schemas;
        foreach my $name (keys %$schemas){
            $validator->set_schema($name, $schemas->{$name});
        }
        
        $self->helper(
            $name => sub {
                my $coll = $class->new(
                    config => $self->config,
                    collection => shift->mango->db->collection($helper->{collection})
                );
                return $coll;
            }
        );
    }    
    
    $self->helper(
        'send_password_key' => sub {
            my ($ctrl, $user) = @_;
            
            my $host = $ctrl->req->url->to_abs->host;
            
            my $callback = sub{
                my ($err, $user) = @_;
                my $original_format = $ctrl->stash->{format};
                my $email_sum = md5_sum $user->{email};
                #my $host = $ctrl->req->url->to_abs->host;
                #my $port = $ctrl->req->url->port;
                my $to = $user->{firstname} ? qq("$user->{firstname}" <$user->{email}>) : $user->{email};
                $ctrl->stash->{key_url} = 
                    $host ."/set-password/". $user->{password_key}{key} ."/". $email_sum;
                $ctrl->stash->{user_firstname} = $user->{firstname};
                my $email = Email::Simple->create(
                    header => [
                        To      => $to,
                        From    => '"PDFUnicorn" <server@pdfunicorn.com>',
                        Subject => "Set your password on PDFUnicorn",
                    ],
                    body => $ctrl->render('email/password_key', partial => 1, format => 'text')
                );
                sendmail($email);
                $ctrl->stash->{format} = $original_format;
            };
            
            # refresh the key if it is more than half the expiry age..
            # refreshing invalidates the old key so we don't want to do it every time
            my $key_created = $user->{password_key}{created}->to_epoch;
            my $expires_seconds = $ctrl->config->{password_key}{expires} * 60/2;
            my $not_before = bson_time->to_epoch - $expires_seconds;
            
            if ($key_created < $not_before){
                $ctrl->db_users->refresh_password_key($ctrl, $user, $callback);
            } else {
                $callback->(undef, $user);
            }
            
        }
    );
    
    $self->helper(
        'invalidate' => sub {
            my ($ctrl, $schema, $data) = @_;
            return $validator->validate($schema, $data);
        }
    );
        
    $self->helper(
        'validate_type' => sub {
            my ($ctrl, $type_name, $data) = @_;
            return $validator->validate_type($type_name, $data);
        }
    );

    $self->helper(
        'app_user_id' => sub {
            shift->session->{user_id};
        }
    );

    $self->helper(
        'api_key' => sub {
            my $ctrl = shift;

            my $auth = $ctrl->req->url->to_abs->userinfo;
            if ($auth){
                my ($token) = $auth =~ /^(.+):/;
                return $token;
            }
            return;            
        }
    );


    # Router
    my $r = $self->routes;

    $r->namespaces(['PDFUnicorn::Ctrl']);
    
    my $api = $r->bridge('/v1')->to(cb => sub {
        my $self = shift;

        my $token = $self->api_key;
        unless ($token){
            $self->render(
                json => {
                    "status" => "missing_apikey",
                    "errors" => ["Sorry, you need to use Basic Authentication with your PDFUnicorn API-Key as the username with no password to access the PDFUnicorn API"]
                },
                status => 401
            );
            return;
        };
        
        # lookup owner and return id
        my $query = { key => $token };

        $self->db_apikeys->find_one($query, sub{
            my ($err, $doc) = @_;
            unless ($doc){
                return $self->render(
                    json => { "status" => "invalid_apikey", "error" => "Sorry, the API-Key you provided is invalid" },
                    status => 401
                );
            };
            $self->stash->{api_key_owner_id} = $doc->{owner};
            $self->continue; # make it so - same as returning true from the bridge
        });
        return;
    });


    my $admin = $r->bridge('/admin')->to(cb => sub {
        my $self = shift;
        
        my $user_id = $self->session->{user_id};
        if (!$user_id){
            $self->render(
                template => "root/log_in",
                error => "Sorry, you need to log in..",
                message => '',
                next_page => '',
                status => 401
            );
            return;
        }
        
        $self->app->db_users->find_one({ _id => bson_oid($user_id)}, sub{
            my ($err, $doc) = @_;
            
            if ($doc && $doc->{active}){
                $self->stash->{app_user} = $doc;
                $self->continue; # make it so - same as returning true from the bridge
            } else {
                # Not authenticated
                $self->render(
                    template => "root/log_in",
                    error => "Sorry, you need to log in..",
                    message => '',
                    next_page => '',
                    status => 401
                );
                return;
            }
        });
        return;
    });

    # Normal route to controller
	$r->get('/')->to('root#home');
	$r->post('/')->to('root#get_pdf');
	
	$r->get('/features')->name('features')->to('root#features');
	$r->get('/pricing')->name('pricing')->to('root#pricing');
	$r->get('/about')->name('about')->to('root#about');
    $r->get('/docs/api')->name('apidocs')->to('root#api_docs');
    $r->get('/docs/markup')->name('markupdocs')->to('root#markup_docs');
    $r->get('/docs/example')->name('example')->to('root#example');

	$r->get('/sign-up')->to('root#sign_up_form');
	$r->post('/sign-up')->to('root#sign_up');
	
	$r->get('/log-in')->to('root#log_in_form');
	$r->post('/log-in')->to('root#log_in');
	
	$r->get('/log-out')->to('root#log_out');
	
	#$r->get('/stripe/connect')->to('stripe#connect');
	
	$r->get('/set-password/:code/:email')->to('root#set_password_form');
	
	$admin->get('/')->to('admin#dash');
	$admin->get('/api-key')->to('admin#apikey');
	$admin->get('/api-docs')->to('admin#api_docs');
    $admin->get('/markup-docs')->to('admin#markup_docs');
    $admin->get('/example')->to('admin#example');
	$admin->get('/billing')->to('admin#billing');
	$admin->post('/get-pdf')->to('admin#get_pdf');
	$admin->post('/set-password')->to('admin#set_password');
	
    $admin->get('/stripe/customer')->to('admin-stripe-customer#find');
    $admin->put('/stripe/customer')->to('admin-stripe-customer#update');
    
    $admin->get('/rest/apikeys')->to('admin-rest-apikeys#find');
    $admin->put('/rest/apikeys/:key')->to('admin-rest-apikeys#update');
    $admin->delete('/rest/apikeys/:key')->to('admin-rest-apikeys#delete');
	
	$api->post('/documents')->to('api-documents#create');
	$api->get('/documents')->to('api-documents#find');
	$api->get('/documents/:id')->to('api-documents#find_one');
	$api->delete('/documents/:id')->to('api-documents#remove');
	
    $api->post('/templates')->to('api-templates#create');
    $api->get('/templates')->to('api-templates#find');
    $api->get('/templates/:id')->to('api-templates#find_one');
    $api->delete('/templates/:id')->to('api-templates#remove');
    
	$api->post('/images')->to('api-images#create');
	$api->get('/images')->to('api-images#find');
	$api->get('/images/:id')->to('api-images#find_one');
	$api->delete('/images/:id')->to('api-images#remove');
	
	if ($self->mode eq 'development' || $self->mode eq 'testing'){
	    # create a test account and api-key
	    
        foreach my $id ('','2','3'){
            my $data = {
                email => "tester${id}\@pdfunicorn.com",
                firstname => "Testy$id",
                password => crypt('bogus', 'ab'),
                active => ($id && $id == 3) ? bson_false : bson_true,
                plan => 'small-1',
            };
            try{
                my $delay = Mojo::IOLoop->delay;
                my $end = $delay->begin;
                $self->db_users->collection->insert($data => sub {
                    my ($collection, $err, $oid) = @_;
                    $self->db_apikeys->collection->insert({
                        owner => $oid,
                        key => "tester${id}s-api-key",
                        name => 'our test key',
                        active => bson_true,
                        deleted => bson_false,
                    });
                    $end->();
                });
                $delay->wait;
            };                
        }
	}
	
}

1;
