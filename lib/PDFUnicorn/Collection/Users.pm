package PDFUnicorn::Collection::Users;
use base 'PDFUnicorn::Collection';
use Moo;
use Mango::BSON ':bson';
#use Mojo::Util qw(md5_sum);
use Time::HiRes 'time';

#use Email::Sender::Simple qw(sendmail);
#use Email::Simple;
#use Email::Simple::Creator;


sub schemas{
    {
        'User', {
            email => { type => 'string', required => 1 },
            firstname => { type => 'string' },
            surname => { type => 'string' },
            uri => { type => 'string' },
            password_key => { type => 'object' },
            password => { type => 'string' },
            timezone => { type => 'string' },
            active => { type => 'boolean', bson => 'bool', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
        },
        'UserQuery', {
            email => { type => 'string' },
            firstname => { type => 'string' },
            surname => { type => 'string' },
            timezone => { type => 'string' },
            password_key => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
        }
    }
}


sub set_password{
    my ($self, $user_id, $password, $salt, $callback) = @_;
    $password = crypt($password, $salt);        
    $self->collection->update(
        { _id => $user_id },
        { '$set' => { password => $password } },
        $callback
    );
}


sub check_password{
    my ($self, $user, $password) = @_;
    my $passhash = crypt($password, $user->{password});
    return 1 if $passhash eq $user->{password};
    return 0;
}

1;
