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
    $self->render();
}

sub about {
	my $self = shift;
    $self->render();
}

sub sign_up_form {
	my $self = shift;
    $self->render(name => '', email => '', error => '');
}

sub sign_up {
	my $self = shift;

	my $name = $self->param('name');
	my $email_addr = $self->param('email');
	my $timezone = $self->param('timezone');
	my $email_length = length($email_addr);
	
	for my $each (($name,$email_addr,$timezone)){
	    next unless $each;
	    $each =~ s/^\s+//;
	    $each =~ s/\s+$//;
	}
	
	unless ($email_addr && $email_addr =~ /^.+\@[^.\s]+\.[^\s]+$/){
        return $self->render(
            #template => 'root/sign_up_form',
            email => $email_addr,
            name => $name,
            error => $email_length ? 'bad_email' : 'missing_email',
        );
	}	
	
	my $error;
	my $user;
	
	my $data = {
        email => $email_addr,
        firstname => $name,
        password_key => $self->random_string(length => 24),
        timezone => $timezone,
        active => bson_true,
    };

    $self->render_later;
	
    $self->db_users->create($data, sub{
        my ($err, $doc) = @_;
        # TODO: Error handling!
        
        if ($doc){
            $self->db_users->send_password_key($doc);
            $self->session->{user_id} = $doc->{_id};
        }
        
        $self->render(
            #template => 'root/sign_up_form',
            email => $doc ? $doc->{email} : $email_addr,
            name => $doc ? $doc->{firstname} : $name,
            error => $err || '',
        );
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

    $self->render_later;

    my $user = $self->db_users->find_one(
        { 'username' => lc($username) },
        sub {
            my ($err, $doc) = @_;
            if ($doc){
                if ($password){
                    if ($self->db_users->check_password($doc, $password)){
                        $self->session->{user_id} = $doc->{_id};
                        $self->redirect_to('/admin');
                        return;
                    }
                } else {
                    $self->db_users->send_password_key($doc);
                    return $self->render(
                        error => '',
                        message => 'I\'ve emailed you a link to reset your password.'
                    );
                }
            }
            $self->render(
                error => 'Sorry, the username/password is incorrect',
                message => '',
            );
            
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
	
    my $user = $self->db_users->find_one({'password_key.key' => $code },
        sub {
            my ($err, $doc) = @_;
            # TODO: Error handling!
            if ($doc){
                my $user_email_hash = md5_sum($doc->{email});
                if ($user_email_hash eq $email_hash){
                    $self->session->{user_id} = $doc->{_id};
                    return $self->render(error => '', user => $doc);
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

sub set_password{
    my $self = shift;
	my $password = $self->param('password');
	$self->db_users->set_password(
        $self->app_user_id, $password,
        $self->random_string(length => 2),
        sub{}
    );
    $self->redirect_to('/');
}


1;
