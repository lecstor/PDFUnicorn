package PDFUnicorn::Ctrl::Root;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use Mojo::JSON;

use Mango::BSON ':bson';

use lib '../PDF-Grid/lib';

use PDF::Grid;

use Try;


sub home {
	my $self = shift;

	# Render template "root/home.html.ep" with message
	$self->render();
}

sub features {
	my $self = shift;
    $self->render();
}

sub pricing {
	my $self = shift;
    $self->render( plans => [sort { $a->{price} <=> $b->{price} } values(%{$self->config->{plans}})] );
}

sub about {
	my $self = shift;
    $self->render();
}

sub sign_up_form {
	my $self = shift;
	my $plan = $self->param('plan');
    $self->render(name => '', email => '', error => '', selected_plan => $plan);
}

sub sign_up {
	my $self = shift;

	my $name = $self->param('name');
	my $email_addr = $self->param('email');
    my $plan_id = $self->param('selected_plan');
	my $timezone = $self->param('timezone');
	my $email_length = length($email_addr);
	my $plan = $self->config->{plans}{$plan_id};
	
	warn "params: $name $email_addr $plan_id";
	warn Data::Dumper->Dumper($self->config->{plans});
	
	foreach my $each (($name,$email_addr,$timezone)){
	    next unless $each;
	    $each =~ s/^\s+//;
	    $each =~ s/\s+$//;
	}
	
	unless ($email_addr && $email_addr =~ /^.+\@[^.\s]+\.[^\s]+$/){
        return $self->render(
            #template => 'root/sign_up_form',
            email => $email_addr,
            name => $name,
            selected_plan => $plan,
            error => $email_length ? 'bad_email' : ($name ? 'missing_email' : 'show_form'),
        );
	}	
	
	my $error;
	my $user;
	
	my $data = {
        email => $email_addr,
        firstname => $name,
        password_key => {
            key => $self->random_string(length => 24),
            created => bson_time,
            reads => [], # [bson_time]
            uses => [], # [bson_time]
        },
        timezone => $timezone,
        active => bson_true,
        password => '',
        plan => $plan,
    };

    if (my $errors = $self->invalidate('User', $data)){
        return $self->render(
            email => $email_addr || '',
            name => $name,
            selected_plan => $plan,
            error => @$errors ? $errors->[0] : '',
            errors => $errors || [],
        );
    }
    
    $self->render_later;
        
    $self->on(finish => sub{
        my $ctrl = shift;
        warn "create stripe customer";
        my $user = $self->stash->{new_user};
        if ($user){
            warn Data::Dumper->Dumper($user);
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
                    warn "new stripe customer: ".Data::Dumper->Dumper([$stripe_customer,$user_id]);
                    $users_collection->update(
                        { _id => $user_id },
                        { '$set' => { stripe_id => $stripe_customer->{id} } },
                        sub {},
                    );
                },
            );
        }
    });
    
    
    $self->db_users->create($data, sub{
        my ($err, $doc) = @_;
        
        if ($err){
            if ($err =~ /^E11000 duplicate key error/){
                # clear the error and send a key
                $err = '';
                return $self->db_users->find_one({ email => $data->{email} }, sub{
                    my ($err, $doc) = @_;
                    #$self->stash->{new_user} = $doc;
                    #warn 'new_user: '.Data::Dumper->Dumper($doc);
            
                    $self->send_password_key($doc) unless $err;
                    
                    $self->stash->{new_user} = $doc unless $doc->{stripe_id};
                    
                    $self->render(
                        email => $data->{email},
                        name => $data->{firstname},
                        error => $err || '',
                        selected_plan => $plan,
                    );
                });
            }
        } else {
            $self->send_password_key($doc);
            $self->session->{user_id} = $doc->{_id};
            $self->stash->{new_user} = $doc;
            warn 'new_user: '.Data::Dumper->Dumper($doc);
            
        }
        
        $self->render(
            email => $doc ? $doc->{email} : $email_addr,
            name => $doc ? $doc->{firstname} : $name,
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
            error => 'Please enter an email address',
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
                    # no password given
                    $self->send_password_key($doc);
                    return $self->render(
                        error => '',
                        message => 'I\'ve emailed you a link to reset your password.'
                    );
                } elsif ($password && $doc->{password}){
                    if ($self->db_users->check_password($doc, $password)){
                        $self->session->{user_id} = $doc->{_id};
                        $self->redirect_to('/admin');
                        return;
                    } else {
                        return $self->render(
                            error => 'Sorry, that password is incorrect',
                            message => '',
                        );
                    }
                } else {
                    # password given and document password exists
                    return $self->render(
                        error => 'You need a password key to access this account. Submit the log in form without a password and I\'ll send you one.',
                        message => ''
                    );
                }
            } else {
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
	
	
	#$self->db_users->find_by_password_key($code, 
    $self->db_users->find_one({'password_key.key' => $code },
        sub {
            my ($err, $doc) = @_;
            # TODO: Error handling!
            if ($doc){
                if (DateTime->from_epoch(epoch => $doc->{password_key}{created}->to_epoch) >= DateTime->now - DateTime::Duration->new(days => 1)){
                    my $user_email_hash = md5_sum($doc->{email});
                    if ($user_email_hash eq $email_hash){
                        
                        $self->session->{user_id} = $doc->{_id};
                        $self->stash->{app_user} = $doc;
                        return $self->render(error => '', user => $doc);
                    }
                } else {
                    return $self->render(
                        template => 'root/log_in',
                        email => '',
                        message => '',
                        error => "Sorry, that account key has expired. Please enter your email address below and I'll send you a new account key.",
                    );
                }
            }
            $self->render(
                template => 'root/log_in',
                email => '',
                message => '',
                error => "Sorry, that account key is invalid. Please enter your email address below and I'll send you a new account key.",
            );
            
        }
    );

}



1;
