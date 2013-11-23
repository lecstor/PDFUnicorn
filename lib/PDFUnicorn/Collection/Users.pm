package PDFUnicorn::Collection::Users;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;


sub create{
    my ($self, $data) = @_;
    
    # validate data here
    
    my $email = $data->{email};
    die 'missing_email' unless $email;
    
    my $time_zone = $data->{time_zone};
    #die 'missing_timezone' unless $time_zone;
    
	$email =~ s/^\s+//;
	$email =~ s/\s+$//;
	
    die 'missing_email' unless $email;
    die 'not_email' if $email =~ /\s/;
    die 'not_email' unless $email =~ /.+\@[^\s.]+\.[^\s.]+/;
    
    my $user = $self->find_one({ 'username' => lc($email) });
    return $user if $user;
    
    $data->{username} = lc($email);
    $data->{time_zone} = $time_zone;
    $data->{created} = bson_time;
    $data->{modified} = $data->{created};
    
    if (my $key = $data->{password_key}){
        $data->{password_key} = {
            key => $key,
            created => bson_time,
            reads => [], # [bson_time]
            uses => [], # [bson_time]
        }
    }
        
    my $oid = $self->collection->insert($data);
    return $self->find_one({ _id => $oid });
}

sub send_password_key{
    my ($self, $user) = @_;
    my $email_sum = md5_sum $user->{email};
    
    #warn "send_password_key.user.firstname: '". $user->{firstname}."'";
    
    my $to = $user->{firstname} ? qq("$user->{firstname}" <$user->{email}>) : $user->{email};
    
    my $email = Email::Simple->create(
        header => [
            To      => $to,
            From    => '"PDFUnicorn" <server@pdfunicorn.com>',
            Subject => "Set your password on PDFUnicorn",
        ],
        body => "http://pdfunicorn.com/set-password/" . $user->{password_key}{key} . "/". $email_sum ."\n",
    );
    sendmail($email);
}

sub set_password{
    my ($self, $user, $password, $salt) = @_;
    $password = crypt($password, $salt);
    #warn "set_password: ".$password;
    #warn "user id: ".$user->{_id};
    
    $user->{password} = $password;
    
    return $self->collection->update( { _id => $user->{_id} }, $user );
}

sub check_password{
    my ($self, $user, $password) = @_;
    #warn "check_password user: ".$user->{password}." pass: ".$password;
    my $passhash = crypt($password, $user->{password});
    #warn $passhash;
    return 1 if $passhash eq $user->{password};
    return 0;
}

1;
