package PDFUnicorn::Template::Alloy;
# ABSTRACT: create document from template and data
use Template::Alloy;


sub new{
    my ($class) = @_;
    
    my $alloy = Template::Alloy->new();

    $alloy->define_vmethod(
        'text',
        epoch => sub{
            my ($value, $format, $offset) = @_;
            $value += $offset*60;
            
            return 'formatted epoch';
        }
    );

    return bless { alloy => $alloy }, $class;   
}

sub render{
    my ($self, $template, $data) = @_;
    my $out = '';
    $self->{alloy}->process(\$template, $data, \$out);
    return $out;
}

1;
