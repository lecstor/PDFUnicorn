package PDFUnicorn::Collection::Documents;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'Document', {
            id => { type => 'string' },
            uri => { type => 'string' },
            type => { type => 'string' },
            #data => { type => 'object' },
            #template => { type => 'string' },
            source => { type => 'string', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'oid', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
            #_required => { or => [qw(source template)] }
        },
        'DocumentQuery', {
            id => { type => 'string' },
            type => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'oid', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
        }
    }
}

=item archive

mark document as deleted and delete it's source property

=cut

sub remove{
    my ($self, $doc, $callback) = @_;
    die 'Need a callback!' unless $callback;
    $self->update({ _id => $doc->{_id} }, {
        deleted => bson_true,
        source => '',
    }, $callback);
}


1;
