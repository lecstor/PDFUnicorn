package PDFUnicorn::Collection::Images;
use base 'PDFUnicorn::Collection';
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);


sub schemas{
    {
        'Image', {
            id => { type => 'string' },
            name => { type => 'string', required => 1 },
            uri => { type => 'string', required => 1 },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
        },
        'ImageQuery', {
            id => { type => 'string' },
            name => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
            public => { type => 'boolean', bson => 'bool' },
            owner => { type => 'string', bson => 'oid' },
        }
    }
}



1;
