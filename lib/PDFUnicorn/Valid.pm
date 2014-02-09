package PDFUnicorn::Valid;
use Moo;

use DateTime;
use Mango::BSON ':bson';

my $SCHEMAS = {};

my $TYPES = {
    'string' => {
        test => sub{ !(ref shift) },
        message => 'cannot be a reference',
    },
    'number' => {
        test => qr/^[\d.]+$/,
        message => 'may only contain digits and periods',
    },
    'integer' => {
        test => qr/^\d+$/,
        message => 'may only contain digits',
    },
    'boolean' => {
        test => qr/^0|1$/,
        message => 'may only be 0 or 1',
    },
    'array' => {
        test => sub{ ref shift eq 'ARRAY' },
        message => 'must be an array',
    },
    'object' => {
        test => sub{ my $o = shift; ref $o && ref $o eq 'HASH' },
        message => 'must be a reference, but not an array',
    },
    'null' => {
        test => sub{ (defined shift) ? 0 : 1 },
        message => 'cannot be anything',
    },
    'any' => {
        test => sub{1},
        message => 'hey, what?',
    },
    
    'date' => { # 1374278400
        test => [
            qr/^\d{10}$/,
            #sub{ DateTime->from_epoch(epoch => shift)->hms eq '00:00:00' },
        ],
        message => 'must be seconds since the epoch with 0 hours, minutes, and seconds, and nanoseconds..',
    },
    
    'datetime' => { # 1374324216.568317
        test => qr/^\d{10}(?:\.\d{0,6})?$/,
        message => 'must be seconds since the epoch',
    },
    
    'oid' => {
        test => qr/^[[:xdigit:]]{24}$/,
        message => 'not a valid oid',
    }
};


sub set_schema{
    my ($self, $name, $schema) = @_;
    $SCHEMAS->{$name} = $schema;
    return $self;
}

sub set_type{
    my ($self, $name, $schema) = @_;
    $TYPES->{$name} = $schema;
    return $self;
}

sub validation_errors{ shift->validate(@_) }

sub validate{
    my ($self, $schema, $data, $errors) = @_;
    # schema is a string or a hash of field => type mappings
    # data is a hash
    
    #warn 'validate data: '. Dumper $data;
    
    my $schema_name = 'ANON';
    
    # if schema is a string, inflate from schema cache
    unless (ref $schema){
        $schema_name = $schema;
        $schema = $SCHEMAS->{$schema};
    }
    
    $errors = [] unless $errors;
        
    if (my $req = $schema->{_required}){
        if ($req->{or}){
            my $ok = 0;
            foreach my $opt (@{$req->{or}}){
                if ($data->{$opt}){
                    $ok = 1;
                    last;
                }
            }
            unless($ok){
                push(@$errors, 'Require attribute, one of: '.join(', ', @{$req->{or}}));
            }
        }
    }
    
    # loop through data attributes
    foreach my $attr_name (keys %$data){

        # verify attr exists in schema
        unless ($schema->{$attr_name}){
            push(@$errors, 'Unexpected object attribute: "'.$attr_name.'"');
            next;
        }
        
        my $attr_schema = $schema->{$attr_name};
        my $trace = $attr_schema->{trace};

        if ($trace){
            warn $schema_name.' '.$attr_name.' '.($data->{$attr_name} || 'undef');
        }

        # skip missing values unless required
        #warn ">>>>> attr_schema->{type}: ".$attr_schema->{type};
        if (!$data->{$attr_name} && ($attr_schema->{type} eq 'boolean' ? (!defined $attr_schema->{type}) : 1)){
            #warn "required: ".($attr_schema->{required} || 0) if $trace;
            next unless $attr_schema->{required};
            push(@$errors, $schema_name.' - Missing required attribute value: "'.$attr_name.'"');
            next;
        }
        
        my $attr_value = $data->{$attr_name};
        my $is_list = ref $attr_schema->{type} eq 'ARRAY' ? 1 : 0;
        my $type = $is_list ? $attr_schema->{type}[0] : $attr_schema->{type};
        
        die $type ." is not a registered Type" unless $TYPES->{$type};
        
        # if it should be a list, verify it is.
        if ($is_list && ref $attr_value ne 'ARRAY'){
            push(@$errors, 'Not an array: "'.$attr_name.'"');
            next;
        }
        
        if ($is_list){
            my @new_list;
            for my $object (@$attr_value){
                push(@new_list, $self->validate_attribute($object, $type, $attr_schema, $attr_name, $errors));
            }
            $data->{$attr_name} = \@new_list;
        } else {
            $data->{$attr_name} = $self->validate_attribute($attr_value, $type, $attr_schema, $attr_name, $errors);
        }
        
    }
    
    # loop through schema attributes checking for missing required attributes.
    foreach my $attr_name (keys %$schema){
        next if exists $data->{$attr_name};
        #next if $data->{$attr_name};
        my $attr_schema = $schema->{$attr_name};
        #warn Dumper([$attr_name, $attr_schema]);
        push(@$errors, $schema_name.' - Missing required attribute value: "'.$attr_name.'"')
            if $attr_schema->{required};
    }
    
    return @$errors ? $errors : undef;
}

sub validate_attribute{
    my ($self, $value, $type, $attr_schema, $attr_name, $errors) = @_;
        
    my $valid = $self->validate_type($type, $value);
    #warn ">>>>>>> $valid";
    unless (defined $valid){
        #warn ">>> error";
        push(@$errors, 'Not a "'.$type.'" in '.$attr_name.' - '.($value||''));
        return $value;
    }
    $value = $valid;
    
    if ($attr_schema->{schema}){
        $self->validate($attr_schema->{schema}, $value, $errors)
    }
    
    if (my $bson_type = $attr_schema->{bson}){
        if ($bson_type eq 'oid'){
            $value = bson_oid $value;
        }elsif ($bson_type eq 'bool'){
            $value = $value ? bson_true : bson_false;
        } elsif ($bson_type eq 'time'){
            $value = bson_time $value;
        } else {
            die "unknown bson type: $bson_type for $attr_name";
        }
    }
    return $value;    
}

sub validate_type{
    my ($self, $type_name, $value) = @_;
    
    my $type = $TYPES->{$type_name};
    
    if (ref $type->{test} ne 'ARRAY'){
        $type->{test} = [$type->{test}];
    } 
    
    foreach my $type_test (@{$type->{test}}){
        my $sch_type = ref $type_test;
        if ($sch_type eq 'CODE'){
            return undef unless &$type_test($value);
        } else {
        #} elsif ($sch_type eq 'Regexp'){
            return undef unless defined $value;
            return undef unless $value =~ $type_test;
        }
    }
    
    if ( $type_name eq 'oid' ){
        $value = bson_oid $value;
    }
        
    return $value;
}



