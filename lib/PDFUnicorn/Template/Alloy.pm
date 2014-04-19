package PDFUnicorn::Template::Alloy;
# ABSTRACT: create document from template and data
use Template::Alloy;
use DateTime;
use Data::Dumper;
use Locale::Currency::Format;


sub new{
    my ($class) = @_;
    
    my $alloy = Template::Alloy->new(
        INCLUDE_PATH => ['pdf_unicorn/templates'],
        START_TAG => '{{',
        END_TAG => '}}',
    );
    my $self = bless { alloy => $alloy }, $class;
    $self->add_vmethods();
    return $self;   
}

sub render{
    my ($self, $template, $data) = @_;
    my $out = '';
    if ($template =~ /<doc/){
        $self->{alloy}->process(\$template, $data, \$out) || die $self->{alloy}->error;
    } else {
        $self->{alloy}->process($template, $data, \$out) || die $self->{alloy}->error;
    }
    return $out;
}

sub add_vmethods{
    my ($self) = @_;

    $self->{alloy}->define_vmethod(
        'text',
        epoch => sub{
            my ($epoch, $options) = @_;
            $options ||= {};

            my $dt = DateTime->from_epoch(
                epoch => $epoch,
                time_zone => $options->{tz} || 'UTC',
                locale => $options->{locale} || 'en_US',
            );
            
            return $self->format_datetime($dt, $options);
        },
    );
    
    $self->{alloy}->define_vmethod(
        'text',
        date => sub{
            my ($value, $options) = @_;
            if ($value =~ /(\d{4})-(\d{2})-(\d{2})/){
                my ($year, $month, $day) = ($1, $2, $3);
                my $dt = DateTime->new(
                    year => $year,
                    month => $month,
                    day => $day
                );
                return $self->format_datetime($dt, $options);
            }
        }
    );

    $self->{alloy}->define_vmethod(
        'text',
        format_price => sub{
            my ($amount, $code, $options) = @_;
            warn "amount $amount code $code";
            $options ||= {};
            $code = uc($code);
            #my $symbol = currency_symbol($code, SYM_UTF);
            #$symbol = '£' if $code eq 'GBP';
            #$symbol = '€' if $code eq 'EUR';
            return ($options->{code} ? $code : '') .currency_format($code, $amount/100, FMT_SYMBOL);
        }
    );
}

sub format_datetime{
    my ($self, $dt, $options) = @_;
    my $date;
    if ($options->{cldr}){
        $date = $dt->cldr($options->{cldr});
    } else {
        my $format = $options->{strf} || '%x';
        $date = $dt->strftime($format);
    }
    $date =~ s/\s{2,}/ /g;
    return $date;
}
    

1;
