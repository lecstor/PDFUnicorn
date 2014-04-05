package PDFUnicorn::Collection::Templates;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'Template', {
            id => { type => 'string' },
            uri => { type => 'string' },
            type => { type => 'string' },
            name => { type => 'string', required => 1 },
            description => { type => 'string' },
            sample_data => { type => 'object' },
            source => { type => 'string', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'oid', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
        },
        'TemplateQuery', {
            id => { type => 'string' },
            type => { type => 'string' },
            name => { type => 'string' },
            description => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'oid', bson => 'oid' },
            deleted => { type => 'boolean', bson => 'bool' },
        }
    }
}

=item archive

mark template as deleted and delete it's source property

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
