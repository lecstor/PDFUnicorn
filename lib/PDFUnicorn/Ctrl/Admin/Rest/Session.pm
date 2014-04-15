package PDFUnicorn::Ctrl::Admin::Rest::Session;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON;


sub collection{ shift->db_users }

sub uri{ 'users' }
sub item_schema{ 'User' }
sub query_schema{ 'UserQuery' }


sub create {
    my $self = shift;
    my $data = $self->req->json();
    my $username = $data->{username};
    my $password = $data->{password};
    
    unless ($username && $password && $username =~ /^.+\@[^.\s]+\.[^\s]+$/){
        return $self->render(
            status => 422,
            json => {
                type => 'invalid_request',
                message => 'Invalid parameters in request',
                errors => ['Please enter your email address and password.'],
            }
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
                        status => 201,
                        json => {
                            message => 'I\'ve emailed you a link to reset your password.',
                        }
                    );
                } elsif ($doc->{password}){
                    if ($self->db_users->check_password($doc, $password)){
                        $self->session->{user_id} = $doc->{_id};
                        return $self->render( json => { ok => 1 } );
                    } else {
                        return $self->render(
                            status => 401,
                            json => {
                                message => 'Invalid parameters in request',
                                errors => ['Sorry, that password is incorrect'],
                            }
                        );
                    }
                } else {
                    # password given but no user password exists
                    $self->res->code(401);
                    return $self->render(
                        status => 401,
                        json => {
                            message => 'Invalid parameters in request',
                            errors => ['You need a password key to access this account. Submit the log in form without a password and I\'ll send you one.'],
                        }
                    );
                }
            } else {
                return $self->render(
                    status => 404,
                    json => {
                        error => 'Sorry, we couldn\'t find an account for that email address.',
                        message => 'Invalid parameters in request',
                    }
                );
            }
            
        }
    );

}

1;

