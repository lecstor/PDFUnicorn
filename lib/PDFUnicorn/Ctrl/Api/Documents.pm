package PDFUnicorn::Ctrl::Api::Documents;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;

sub collection{ shift->db_documents }

sub item_schema{ 'Document' }
sub query_schema{ 'DocumentQuery' }

1;
