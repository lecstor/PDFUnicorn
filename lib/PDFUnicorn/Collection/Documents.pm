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
            owner => { type => 'string', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
            #_required => { or => [qw(source template)] }
        },
        'DocumentQuery', {
            id => { type => 'string' },
            type => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
        }
    }
}

=item archive

mark document as archived and delete it's source property

=cut

sub archive{
    my ($self, $doc, $sub) = @_;
    $doc->{archived} = bson_true;
    delete $doc->{source};
    $self->update({ _id => $doc->{_id} }, $doc, $sub);
}


1;
