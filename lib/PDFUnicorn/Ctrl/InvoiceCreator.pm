package PDFUnicorn::Ctrl::InvoiceCreator;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(md5_sum);
use JSON;

use Mango::BSON ':bson';
#use Mojo::ByteStream 'b';

use lib '../PDF-Grid/lib';

use PDF::Grid;



sub home{
	my $self = shift;

	$self->render();
}



1;
