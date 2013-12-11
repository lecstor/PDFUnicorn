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

sub get_pdf{
	my $self = shift;
	my $data = $self->param('data');
	my $tmpl = $self->param('template');

    my $pdf = PDF::Grid->new({
        source => $tmpl,
        data => $data,
    });
    $pdf->render_template;
    $pdf->producer->saveas('pdf_unicorn_demo1.pdf');    
    $pdf->producer->end;

    $self->render_file(
        'filepath' => 'pdf_unicorn_demo1.pdf',
        'format'   => 'pdf',                 # will change Content-Type "application/x-download" to "application/pdf"
        'content_disposition' => 'inline',   # will change Content-Disposition from "attachment" to "inline"
    );
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
    $self->render(name => '', email => '');
}

sub sign_up {
	my $self = shift;

	my $name = $self->param('name');
	my $email_addr = $self->param('email');
	my $time_zone = $self->param('time_zone');
	my $error;
	my $user;
	
	try {
        $user = $self->db_users->create({
            email => $email_addr,
            firstname => $name,
            is_user => 1,
            password_key => $self->random_string(length => 24),
            time_zone => $time_zone,
        });
	}
	catch {
	    when (/not_email/){
	        $error = 'not_email';
	    }
	    when (/missing_email/){
	        $error = 'missing_email';
	    }
	    default { die $_; }
	};

    if ($user){
        $self->db_users->send_password_key($user);
        $self->session->{user} = $user;
    }

    $self->render(
        #template => 'root/sign_up_form',
        email => $user ? $user->{email} : $email_addr,
        name => $user ? $user->{firstname} : $name,
        error => $error,
    );
	
}

sub log_in_form {
	my $self = shift;
    $self->render(
        template => 'root/log_in',
        error => ''
    );
}

sub log_in{
    my $self = shift;
	my $username = $self->param('username');
	my $password = $self->param('password');
    my $user = $self->db_users->find_one({ 'username' => lc($username) });
    if ($user){
        if ($self->db_users->check_password($user, $password)){
            $self->session->{user} = $user;
            $self->redirect_to('/');
            return;
        }
    }
    $self->render(
        error => 'Sorry, the username/password is incorrect'
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

    my $user = $self->db_users->find_one({'password_key.key' => $code });

    if ($user){
        my $user_email_hash = md5_sum($user->{email});
        if ($user_email_hash eq $email_hash){
            $self->session->{user} = $user;
            return $self->render(error => undef, user => $user);
        }
        return $self->render(
            template => 'root/log_in',
            email => undef,
            error => "Sorry, that account key is invalid. Please enter your email address below and I'll send you a new account key.",
        );
    }
    $self->render(
        template => 'root/log_in',
        email => undef,
        error => "Sorry, that account key is invalid. Please enter your email address below and I'll send you a new account key.",
    );
    
}

sub set_password{
    my $self = shift;
	my $password = $self->param('password');
	my $user = $self->auth_user;
	$self->db_users->set_password($user, $password, $self->random_string(length => 2));
    $self->redirect_to('/');
}


1;
