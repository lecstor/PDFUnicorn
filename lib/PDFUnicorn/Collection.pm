package PDFUnicorn::Collection;
use Moo;
use Mango::BSON ':bson';
use DateTime;
use Try;
use Time::HiRes 'time';

has collection => (
    is => 'ro',
);

has config => (
    is => 'ro',
);

# sub schemas{}

sub create{
    my ($self, $data, $callback) = @_;
    die 'Need a callback!' unless $callback;
 
    $data->{created} = bson_time; # note Time::HiRes 'time'
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

=item find_and_modify

my $opts = {
    query => { foo => 'bar' },
    update => { '$set' => {foo => 'baz'} }
};

$collection->find_and_modify($opts => sub {
  my ($collection, $err, $doc) = @_;
  ...
});

=cut

sub find_and_modify{
    my ($self, $query_update, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->collection->find_and_modify($query_update, $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub find_one{
    my ($self, $query, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->collection->find_one($query => sub{
        my ($coll, $err, $doc) = @_;
        warn $err if $err;
        $callback->($err, $doc);
    });
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running; 
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
    delete $data->{created};
    $data->{modified} = bson_time; # note Time::HiRes 'time'
    my $callback = ref($_[-1]) eq 'CODE' ? pop : undef;
    my $options = shift || {};
    die 'Need a callback!' unless $callback;
    $self->collection->find_and_modify({
        query => $query,
        update => { '$set' => $data }
    }, $callback);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


sub remove{
    my ($self, $doc, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->update({ _id => $doc->{_id} }, { deleted => bson_true }, $callback);
}

1;
