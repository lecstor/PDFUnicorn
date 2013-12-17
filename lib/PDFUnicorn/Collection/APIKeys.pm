package PDFUnicorn::Collection::APIKeys;
use base 'PDFUnicorn::Collection';
use Moo;
use Mango::BSON ':bson';
use Mojo::Util qw(md5_sum);
use Time::HiRes 'time';


sub schemas{
    {
        'APIKey', {
            owner => { type => 'string', bson => 'oid' },
            name => { type => 'string' },
            active => { type => 'boolean', bson => 'bool' },
            trashed => { type => 'boolean', bson => 'bool' },
            key => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
        },
        'APIKeyQuery', {
            owner => { type => 'string', bson => 'oid' },
            name => { type => 'string' },
            active => { type => 'boolean', bson => 'bool' },
            trashed => { type => 'boolean', bson => 'bool' },
            key => { type => 'string' },
            created => { type => 'datetime', bson => 'time' },
            modified => { type => 'datetime', bson => 'time' },
        }
    }
}


1;
