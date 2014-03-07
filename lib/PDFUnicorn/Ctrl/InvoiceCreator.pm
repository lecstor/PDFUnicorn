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

sub pdf{
    my $self = shift;

    my $params = $self->req->params->to_hash;
    warn Data::Dumper->Dumper($params);

    my $items = [];
    for my $key (keys %$params){
        next unless $key =~ /item_(\w+)_(\d+)/;
        warn "matched: $key";
        my ($field, $number) = ($1,$2);
        warn "field: $field number: $number";
        $items->[$number+0] ||= {};
        $items->[$number+0]{$field} = $params->{$key};
    }
    warn Data::Dumper->Dumper($items);

    my @recipient = split(/\r?\n/, $params->{invoice_recipient});
    my @sender = split(/\r?\n/, $params->{invoice_sender});

    my $data = {
        invoice => {
            recipient_name => shift @recipient,
            recipient_address => \@recipient,
            sender_name => shift @sender,
            sender_address => \@sender,
            head => [split(/\r?\n/, $params->{invoice_head})],
            foot => [split(/\r?\n/, $params->{invoice_foot})],
            number => $params->{invoice_number},
            date => $params->{invoice_date},
            payment_due_date => $params->{payment_due_date},
            currency => $params->{currency},
            total => $params->{invoice_total},
            sub_total => $params->{invoice_subtotal},
            tax_amount => $params->{invoice_tax_subtotal},
            tax_name => $params->{tax_name},
            purchase_order => $params->{tax_name},
            title => $params->{invoice_title},
        },
        items => $items,
    };
    
    warn Data::Dumper->Dumper($data);

    my $source = eval{ $self->alloy->render('invoice_maker/invoice_01.puml', $data) };
    if (my $err = $@){
        # Template::Exception
        warn $err->as_string;
        my $message = $err->as_string;
        $message =~ s/.*\s\-\s//;
        return $self->render(
            template => 'invoice_creator/home',
            error => 'Template Error: '.$message,
            time => time
        );
    }
    
    warn "SOURCE: $source";

    my $grid = PDF::Grid->new({
        media_directory => 'pdf_unicorn/images', #$self->config->{media_directory}.'/tryit/',
        #media_directory => 'pdf_unicorn/images/tester', #$self->config->{media_directory}.'/tryit/',
        source => $source,
    });
    
    eval{ $grid->render };
    if (my $err = $@){
        warn $err->message;
        my $message = $err->message;
        $message =~ s/\s+at \/.*//;
        return $self->render(
            template => 'root/playground_form',
            error => $message,
            time => time
        );
    }

    my $pdf_doc = $grid->producer->stringify();    
    $grid->producer->end;
            
    $self->res->headers->content_type("application/pdf");
    if ($params->{mode} eq 'view'){
        $self->res->headers->content_disposition('inline; filename=pdfunicorn.com-tryit.pdf;');
    } else {
        $self->res->headers->content_disposition('attachment; filename=pdfunicorn.com-tryit.pdf;');
    }
    $self->render( data => $pdf_doc );

}


1;
