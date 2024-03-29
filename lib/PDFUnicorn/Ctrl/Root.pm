package PDFUnicorn::Ctrl::Root;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use JSON;

use Mango::BSON ':bson';
#use Mojo::ByteStream 'b';

use lib '../PDF-Grid/lib';

use PDF::Grid;



sub home {
	my $self = shift;

	# Render template "root/home.html.ep" with message
	$self->render();
}

sub features {
	my $self = shift;
    $self->render();
}

sub contact {
    my $self = shift;
    $self->render();
}

sub pricing {
	my $self = shift;
    $self->render( plans => [sort { $a->{templates} <=> $b->{templates} } values(%{$self->config->{plans}})] );
}

sub annual_pricing {
    my $self = shift;
    $self->render( template => 'root/pricing', plans => [sort { $a->{templates} <=> $b->{templates} } values(%{$self->config->{annual_plans}})] );
}

sub about {
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

#sub sign_up_form {
#	my $self = shift;
#	my $plan = $self->param('plan');
#    $self->render(firstname => '', surname => '', email => '', error => '', selected_plan => $plan);
#}

sub sign_up {
	my $self = shift;

    my $firstname = $self->param('firstname');
    my $surname = $self->param('surname');
    my $email_addr = $self->param('email');
    my $plan_id = $self->param('selected_plan');
    my $timezone = $self->param('timezone');
    my $email_length = length($email_addr);
    my $plan = { name => 'notifications' };
    if ($plan_id){
        $plan = $self->config->{plans}{$plan_id} || $self->config->{annual_plans}{$plan_id};
    }
    
	foreach my $each (($firstname,$surname,$email_addr,$timezone)){
	    next unless $each;
	    $each =~ s/^\s+//;
	    $each =~ s/\s+$//;
	}
	
	unless ($email_addr && $email_addr =~ /^.+\@[^.\s]+\.[^\s]+$/){
        return $self->render(
            email => $email_addr,
            firstname => $firstname,
            surname => $surname,
            selected_plan => $plan,
            error => $email_length ? 'bad_email' : ($firstname ? 'missing_email' : 'show_form'),
        );
	}	
	
	my $error;
	my $user;
	
	my $data = {
        email => $email_addr,
        firstname => $firstname,
        surname => $surname,
        password_key => {
            key => $self->random_string(length => 24),
            created => bson_time,
            reads => [],
            uses => []
        },
        timezone => $timezone,
        active => bson_true,
        password => '',
        plan => $plan,
    };

#    if (my $errors = $self->invalidate('User', $data)){
#        return $self->render(
#            email => $email_addr || '',
#            name => $name,
#            selected_plan => $plan,
#            error => @$errors ? $errors->[0] : '',
#            errors => $errors || [],
#        );
#    }
    
    $self->render_later;
        
    $self->on(finish => sub{
        my $ctrl = shift;
        my $user = $self->stash->{new_user};
        if ($user){
            my $user_id = $user->{_id};
            my $users_collection = $ctrl->db_users;
            my $customer = $self->stripe->customers->create(
                {
                    plan => $user->{plan}{id},
                    email => $user->{email},
                    #metadata => { pdfu_id => $user_id }, # this breaks it.
                },
                sub{
                    my ($client, $stripe_customer) = @_;
                    $users_collection->update(
                        { _id => $user_id },
                        { stripe_id => $stripe_customer->{id} },
                        sub {},
                    );
                },
            );
        }
    });
    
    
    $self->db_users->create($data, sub{
        my ($err, $doc) = @_;
        
        if ($err){
            if ($err =~ /E11000 duplicate key error/){
                # clear the error and send an account key
                $err = '';
                return $self->db_users->find_one({ email => $data->{email} }, sub{
                    my ($err, $doc) = @_;
            
                    $self->send_password_key($doc) unless $err;
                    
                    $self->stash->{new_user} = $doc unless $doc->{stripe_id};
                    
                    $self->render(
                        email => $data->{email},
                        firstname => $data->{firstname},
                        surname => $data->{surname},
                        error => $err || '',
                        selected_plan => $plan,
                    );
                });
            }
        } else {
            $self->send_alert_notifications_signup($doc);
            if ($plan->{name} eq 'notifications'){
                $self->send_thankyou_notifications_signup($doc);
            } else {
                $self->send_password_key($doc);
                $self->session->{user_id} = $doc->{_id};
                $self->stash->{new_user} = $doc;
            }
        }
        
        $self->render(
            email => $doc ? $doc->{email} : $email_addr,
            firstname => $doc ? $doc->{firstname} : $firstname,
            surname => $doc ? $doc->{surname} : $surname,
            error => $err || '',
            selected_plan => $plan,
        );
        
        return 0;
        
    });
	
}

sub log_in_form {
	my $self = shift;
    $self->render(
        template => 'root/log_in',
        error => '',
        message => ''
    );
}

sub log_in{
    my $self = shift;
	my $username = $self->param('username');
	my $password = $self->param('password');

    unless ($username && $username =~ /^.+\@[^.\s]+\.[^\s]+$/){
        return $self->render(
            #template => 'root/sign_up_form',
            email => $username,
            error => 'Please enter the email address you signed up with',
            message => '',
        );
    }   
    
    $self->render_later;

    my $user = $self->db_users->find_one(
        { 'email' => lc($username) },
        sub {
            my ($err, $doc) = @_;
            if ($doc){
                if (!$password){
                    # no password given - send email key
                    $self->send_password_key($doc);
                    return $self->render(
                        error => '',
                        message => 'I\'ve emailed you a link to reset your password.'
                    );
                } elsif ($doc->{password}){
                    if ($self->db_users->check_password($doc, $password)){
                        $self->session->{user_id} = $doc->{_id};
                        $self->redirect_to('/admin');
                        return;
                    } else {
                        $self->res->code(401);
                        return $self->render(
                            error => 'Sorry, that password is incorrect',
                            message => '',
                        );
                    }
                } else {
                    # password given but no user password exists
                    $self->res->code(401);
                    return $self->render(
                        error => 'You need a password key to access this account. Submit the log in form without a password and I\'ll send you one.',
                        message => ''
                    );
                }
            } else {
                $self->res->code(404);
                return $self->render(
                    error => 'Sorry, we couldn\'t find an account for that email address.',
                    message => '',
                );
            }
            
        }
    );
    
}

sub log_out{
    my $self = shift;
    $self->session(expires => 1);
    $self->redirect_to('/');
}

sub set_password_form{
    my $self = shift;
    
    my $code = $self->stash->{code};
    my $email_hash = $self->stash->{email};
    delete $self->stash->{code};
    delete $self->stash->{email};

    $self->render_later;
    
    $self->db_users->find_one({'password_key.key' => $code },
        sub {
            my ($err, $doc) = @_;
            if ($doc){
                # TODO: Error handling!                
                my $key_created = $doc->{password_key}{created}->to_epoch;
                my $expires_seconds = $self->config->{password_key}{expires} * 60;
                my $not_before = bson_time->to_epoch - $expires_seconds;
                
                if ($key_created >= $not_before){
                    my $user_email_hash = md5_sum($doc->{email});
                    if ($user_email_hash eq $email_hash){
                        $self->session->{user_id} = $doc->{_id};
                        $self->stash->{app_user} = $doc;
                        return $self->render(error => '', user => $doc);
                    }
                } else {
                    $self->send_password_key($doc);
                    return $self->render(
                        template => 'root/log_in',
                        email => '',
                        message => '',
                        error => "Sorry, that account key has expired. I have sent a new key to your email address.",
                    );
                }
                
                $self->render(
                    template => 'root/log_in',
                    email => '',
                    message => '',
                    error => "Sorry, that account key is invalid. Please enter your email address below and I'll send you a new account key.",
                );

            } else {
                $self->render(
                    template => 'root/log_in',
                    email => '',
                    message => '',
                    error => "Sorry, that account key is invalid. Please enter your email address below and I'll send you a new account key.",
                );
            }            
                        
        }
    );

}

sub demo_form{
    my $self = shift;
    $self->render(error => '', time => time);
}

sub demo{
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
    
#    warn $source;
    
    #return;
    
    my $grid = PDF::Grid->new({
        media_directory => 'pdf_unicorn/images', #$self->config->{media_directory}.'/tryit/',
        #media_directory => 'pdf_unicorn/images/tester', #$self->config->{media_directory}.'/tryit/',
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
