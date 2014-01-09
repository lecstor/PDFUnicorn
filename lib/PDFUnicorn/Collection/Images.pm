package PDFUnicorn::Collection::Images;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'Image', {
            id => { type => 'string' },
            src => { type => 'string', required => 1 },
            uri => { type => 'string', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            stock => { type => 'boolean', bson => 'bool' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
        },
        'ImageQuery', {
            id => { type => 'string' },
            src => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            stock => { type => 'boolean', bson => 'bool' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
        }
    }
}


sub remove{
    my ($self, $doc, $sub) = @_;
    $doc->{deleted} = bson_true;
    my $media_dir = $self->config->{media_directory};
    unlink($media_dir.'/'.$doc->{owner}.'/'.$doc->{src});
    $self->update({ _id => $doc->{_id} }, $doc, $sub);
}


1;
