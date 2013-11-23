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
    my ($self, $data, $callback) = @_;
    die 'Need a callback!' unless $callback;
 
    $data->{created} = time; # note Time::HiRes 'time'
    $data->{modified} = $data->{created};
        
    my $oid = $self->collection->insert($data);
    
    $self->collection->save($data, sub{
        my ($coll, $err, $oid) = @_;
        $self->find_one({ _id => $oid }, $callback);
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;    
}

# no non-blocking find?
sub find{
    my ($self, $query) = @_;
    return $self->collection->find($query);
}

sub find_and_modify{
    my ($self, $query, $callback) = @_;
    $self->collection->find_and_modify($query, $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub find_one{
    my ($self, $query, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->collection->find_one($query => sub{
        my ($coll, $err, $doc) = @_;
        warn Data::Dumper->Dumper([$err, $doc]);
        $callback->($err, $doc);
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub find_all{
    my ($self, $query, $callback) = @_;
    die 'Need a callback!' unless $callback;
    my $cursor = $self->collection->find($query);
    $cursor->all($callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub update{
    my ($self, $query, $data, $callback) = @_;
    die 'Need a callback!' unless $callback;
    #return $self->collection->update($query, $data);
    $self->collection->update(($query, $data) => $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


1;
