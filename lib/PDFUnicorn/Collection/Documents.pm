package PDFUnicorn::Collection::Documents;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'Document', {
            id => { type => 'string' },
            name => { type => 'string', required => 1 },
            type => { type => 'string' },
            data => { type => 'object' },
            source => { type => 'string', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
            images => { type => 'object' },
            #_required => { or => [qw(source template)] }
        },
        'DocumentQuery', {
            id => { type => 'string' },
            name => { type => 'string' },
            type => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            archived => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
        }
    }
}

#sub create{
#    my ($self, $data) = @_;
#    
#    # validate data here
#    die 'missing_id' unless $data->{id};
#    die 'missing_name' unless $data->{name};
#    die 'missing_data' unless $data->{data};
#    $data->{type} ||= 'source';
#            
#    my $oid = $self->collection->insert($data);
#    
#    return $self->find_one({ _id => $oid });
#}



1;
