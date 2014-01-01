package PDFUnicorn::Collection::Users;
use base 'PDFUnicorn::Collection';
use Moo;
use Mango::BSON ':bson';
#use Mojo::Util qw(md5_sum);
use Time::HiRes 'time';
use Session::Token;

#use Email::Sender::Simple qw(sendmail);
#use Email::Simple;
#use Email::Simple::Creator;


sub schemas{
    {
        'User', {
            email => { type => 'string', required => 1 },
            firstname => { type => 'string' },
            surname => { type => 'string' },
            plan => { type => 'object' },
            stripe_id => { type => 'string' },
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
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
        }
    }
}


sub set_password{
    my ($self, $user_id, $password, $salt, $callback) = @_;
    $password = crypt($password, $salt);        
    $self->update(
        { _id => $user_id },
        { '$set' => { password => $password } },
        $callback
    );
}


sub refresh_password_key{
    my ($self, $user, $callback) = @_;
    $self->update(
        { _id => $user->{_id} },
        { 
            password_key => {
                key => Session::Token->new(length => 24)->get,
                created => bson_time,
                reads => [], # [bson_time]
                uses => [], # [bson_time]
            },
        },
        sub{
            my ($collection, $err, $doc) = @_;
            warn $err if $err;
            $callback->($self, $err, $doc);
        }
    );
}

#sub find_by_password_key{
#    my ($self, $key, $callback) = @_;
#    $self->find_one({'password_key.key' => $key },
#    sub{
#        my ($err, $doc) = @_;
#        if ($doc){
#            if (DateTime->from_epoch(epoch => $doc->{password_key}{created}->to_epoch) < DateTime->now - DateTime::Duration->new(days => 1)){
#                # callback gets called without user doc as key was invalid
#                $self->refresh_password_key($doc, sub{ my ($err, $doc) = @_; $callback->($err) });
#            } else {
#                $callback->($self, $err, $doc);
#            }
#        } else {
#            $callback->($self, $err);
#        }
#    });
#}

sub check_password{
    my ($self, $user, $password) = @_;
    my $passhash = crypt($password, $user->{password});
    return 1 if $passhash eq $user->{password};
    return 0;
}

1;
