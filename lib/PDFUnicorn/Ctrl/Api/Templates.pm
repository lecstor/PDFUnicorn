package PDFUnicorn::Ctrl::Api::Templates;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use Mojo::IOLoop;

sub collection{ shift->db_documents }

sub uri{ 'templates' }
sub item_schema{ 'Template' }
sub query_schema{ 'TemplateQuery' }


1;
