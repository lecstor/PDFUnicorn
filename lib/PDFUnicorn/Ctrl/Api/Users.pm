package PDFUnicorn::Ctrl::Api::Users;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON;
use Try;

sub create {
	my $self = shift;
    
    my $data = $self->req->json();
    
	my $response = { ok => 0 };
    my $user;
    
	try {
        $user = $self->db_users->create({
            email => $data->{email},
            firstname => $data->{firstname},
            surname => $data->{surname},
            is_user => 1,
            password_key => $self->random_string(length => 24),
        });
    }
	catch {
	    when (/not_email/){
	        $response->{errors} = ["Sorry, that doesn't look like an email address to me.."];
	    }
	    when (/missing_email/){
	        $response->{errors} = ["Sorry, you need to enter an email address.."];
	    }
	    default { warn "die"; die $self->dumper($_); }
	};

    if ($user){
        $response->{data} = $user;
        $response->{ok} = 1;
        $self->db_users->send_password_key($user);
        $self->session->{user} = $user->{_id};
    }
    
    $self->render(json => $response);
}

1;

