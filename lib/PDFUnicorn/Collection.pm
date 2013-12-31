package PDFUnicorn::Collection;
use Moo;
use Mango::BSON ':bson';
use DateTime;
use Try;
use Time::HiRes 'time';

has collection => (
    is => 'ro',
);

# sub schemas{}

sub create{
    my ($self, $data, $callback) = @_;
    die 'Need a callback!' unless $callback;
 
    $data->{created} = time; # note Time::HiRes 'time'
    $data->{modified} = $data->{created};
        
    my $oid = $self->collection->insert($data => sub{
        my ($coll, $err, $oid) = @_;
        return $callback->($err) if $err;
        $self->find_one({ _id => $oid }, $callback);
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;    
}

# hm different to find_all in the args we call the callback with.
#sub find{
#    my ($self, $query, $callback) = @_;
#    my $cursor = $self->collection->find($query);
#    if ($callback){
#        $cursor->all(sub {
#            my ($cursor, $err, $docs) = @_;
#            $callback->($docs);
#        });
#        Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
#    } else {
#        return $cursor->all;
#    }
#}

sub find_and_modify{
    my ($self, $query, $callback) = @_;
    $self->collection->find_and_modify($query, $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub find_one{
    my ($self, $query, $callback) = @_;
    if ($callback){
        $self->collection->find_one($query => sub{
            my ($coll, $err, $doc) = @_;
            warn $err if $err;
            $callback->($err, $doc);
        });
        Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    } else {
        return $self->collection->find_one($query);
    }
    
}

sub find_all{
    my ($self, $query, $callback, $fields) = @_;
    die 'Need a callback!' unless $callback;
    my $cursor = $self->collection->find($query, $fields);
    $cursor->all($callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


=item

    Args:
        - hashref defining find filters
        - hashref of update data
        - callback

    $callback->($collection, $err, $doc);

=cut

sub update{
    my $self = shift;
    my $query = shift;
    my $data = shift;
    my $callback = ref($_[-1]) eq 'CODE' ? pop : undef;
    my $options = shift || {};
    #my ($self, $query, $data, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->collection->update(($query, $data, $options) => $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


1;
