package PDFUnicorn::Ctrl::Api::Users;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON;
use Try;


sub collection{ shift->db_users }

sub uri{ 'users' }
sub item_schema{ 'User' }
sub query_schema{ 'UserQuery' }


sub create {
	my $self = shift;
    
	my $response = { ok => 0 };

    my $user_data = {
        email => $data->{email},
        firstname => $data->{firstname},
        surname => $data->{surname},
        password_key => {
            key => $self->random_string(length => 24),
            created => bson_time,
            reads => [], # [bson_time]
            uses => [], # [bson_time]
        }
    };
    
    my $data = $self->req->json();
    if (my $errors = $self->invalidate($self->item_schema, $user_data)){
        return $self->render(
            status => 422,
            json => { status => 'invalid_request', data => { errors => $errors } }
        );
    }
    
    $self->render_later;
    
    my $user = $self->collection->create($user_data, sub{
        my ($err, $doc) = @_;
        if ($doc){
            $response->{data} = $doc;
            $response->{ok} = 1;
            $self->send_password_key($doc);
            $self->session->{user} = $doc;
        }
        $self->render(json => $response);
    });

}

1;

