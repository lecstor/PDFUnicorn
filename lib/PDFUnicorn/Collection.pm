package PDFUnicorn::Collection;
use Moo;
use Mango::BSON ':bson';
use Data::Dumper::Perltidy;
use DateTime;
use Try;
use Time::HiRes 'time';

has collection => (
    is => 'ro',
);

sub schemas{}

sub create{
    my ($self, $data) = @_;
 
    $data->{created} = time; # note Time::HiRes 'time'
    $data->{modified} = $data->{created};
        
    my $oid = $self->collection->insert($data);
    return $self->find_one({ _id => $oid });
}

sub find{
    my ($self, $query) = @_;
    unless (exists $query->{archived}){
        $query->{archived} = undef;
    }
    return $self->collection->find($query);
}

sub find_one{
    my ($self, $query) = @_;
    #warn Dumper $query;
    return $self->collection->find_one($query);
}

sub update{
    my ($self, $query, $data) = @_;
    return $self->collection->update($query, $data);
}


1;
