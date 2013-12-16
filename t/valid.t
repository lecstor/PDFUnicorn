use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use PDFUnicorn::Valid;
use DateTime;
use Data::Dumper::Perltidy;
use Clone qw(clone);


my $valid = PDFUnicorn::Valid->new();

my $types = {
    'string' => [
        [1, "This is a string"],
        [0, []],
    ],
    'number' => [
        [1, 0],
        [1, 1],
        [1, 1.453],
        [0, ''],
        [0, 'not a number'],
    ],
    'integer' => [
        [1, 0],
        [1, 1],
        [0, 1.453],
        [0, ''],
        [0, 'not an integer'],
    ],
    'boolean' => [
        [1, 0],
        [1, 1],
        [0, 1.453],
        [0, ''],
        [0, 'not an integer'],
    ],
    'array' => [
        [1, []],
        [0, {}],
        [0, sub{}],
        [0, 0],
        [0, 1],
        [0, 1.453],
        [0, ''],
    ],
    'object' => [
        [1, {}],
        [0, sub{}],
        [0, 0],
        [0, 1],
        [0, 1.453],
        [0, ''],
    ],
    'null' => [
        [1, undef],
        [0, sub{}],
        [0, 0],
        [0, 1],
        [0, 1.453],
        [0, ''],
    ],
    'any' => [
        [1, undef],
        [1, sub{}],
        [1, 0],
        [1, 1],
        [1, 1.453],
        [1, ''],
    ],
    'date' => [
        [0, '1374324216.568317'],
        [0, '1374324216'],
        [1, '1374278400'],
        [0, undef],
        [0, sub{}],
        [0, 0],
        [0, 1],
        [0, 1.453],
        [0, ''],
    ],
    'datetime' => [
        [1, '1374324216.568317'],
        [0, undef],
        [0, sub{}],
        [0, 0],
        [0, 1],
        [0, 1.453],
        [0, ''],
    ],
    
};

#my $result;
#
#for my $type (keys %$types){
#    my $cnt = 0;
#    foreach my $test (@{$types->{$type}}){
#        $result = $valid->validate_type($type, $test->[1]);
#        ok($result == $test->[0], "type: $type test: $cnt result: $result data: ". $test->[1]);
#        $cnt++;
#    }
#}

$valid->set_schema(
    'Day', {
        _id => { type => 'oid' },
        name => { type => 'string', required => 1, trace => 1 },
        user => { type => 'string', required => 1 },
        day => { type => 'date', required => 1 },
        created => { type => 'datetime' },
        modified => { type => 'datetime' },
        meals => { type => ['object'], schema => 'Meal' }
    }
);

$valid->set_schema(
    'Meal', {
        _id => { type => 'string', bson=>'oid' },
        name => { type => 'string', required => 1 },
        user => { type => 'string', required => 1 },
        created => { type => 'datetime' },
        modified => { type => 'datetime' },
        recipes => { type => ['object'], schema => 'Recipe' },
        public => { type => 'boolean', bson => 'bool' },
    }
);

$valid->set_schema(
    'Recipe', {
        _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/ },
        name => { type => 'string', required => 1 },
        user => { type => 'string', required => 1 },
        created => { type => 'datetime' },
        modified => { type => 'datetime' },
        ingredients => { type => ['object'], schema => 'Ingredient' },
        steps => { type => ['object'], schema => 'Step' },
        public => { type => 'boolean', bson => 'bool' },
    }
);

my $day = {
    _id => '123456789012345678901234',
    name => 'Jun 23',
    user => 'abc123',
    day => '1374278400',
    created => '1374324216.568317',
    modified => '1374324216.568317',
    meals => [{
        _id => '123456789012345678901234',
        name => 'Crumbed Chicken Meal',
        user => 'abc123',
        created => '1374324216.568317',
        modified => '1374324216.568317',
        recipes => [{
            _id => '123456789012345678901234',
            name => 'Crumbed Chicken Recipe',
            user => 'abc123',
            created => '1374324216.568317',
            modified => '1374324216.568317',
        }]
    }]
};

my $res = $valid->validate('Day', clone($day));
ok(!$res);

delete $day->{name};
$res = $valid->validate('Day', clone($day));
ok($res);
is(@$res, 1);
is($res->[0], 'Day - Missing required attribute value: "name"');

$day->{name} = '';
$res = $valid->validate('Day', clone($day));
ok($res);
is(@$res, 1);
is($res->[0], 'Day - Missing required attribute value: "name"');

$day->{name} = 'Jun 23';
$day->{created} = 'ggg';
$res = $valid->validate('Day', clone($day));
ok($res);
is(@$res, 1);
is($res->[0], q!Not a "datetime" in created - ggg!);
$day->{created} = '1374324216.568317';

$day->{not_required} = '';

$res = $valid->validate({
    _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/ },
    name => { type => 'string', required => 1 },
    user => { type => 'string', required => 1 },
    not_required => { type => 'string' },
    day => { type => 'date', required => 1 },
    created => { type => 'datetime' },
    modified => { type => 'datetime' },
    meals => { type => ['object'], schema => 'Meal' }
}, clone($day));
ok(!$res);

throws_ok { 
    $valid->validate({
        _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/ },
        name => { type => 'string', required => 1 },
        user => { type => 'string', required => 1 },
        not_required => { type => 'string' },
        day => { type => 'date', required => 1 },
        created => { type => 'datetime' },
        modified => { type => 'datetime' },
        meals => { type => ['not_a_type'], schema => 'Meal' }
    }, clone($day))
} qr/not_a_type is not a registered Type/, 'non-type caught okay';

my $meals = $day->{meals};
$day->{meals} = 'sdfsdf';

$res = $valid->validate({
    _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/, bson => 'oid' },
    name => { type => 'string', required => 1 },
    user => { type => 'string', required => 1 },
    not_required => { type => 'string' },
    day => { type => 'date', required => 1 },
    created => { type => 'datetime' },
    modified => { type => 'datetime' },
    meals => { type => ['object'], schema => 'Meal' }
}, clone($day));
is(@$res, 1);
is($res->[0], q!Not an array: "meals"!);

$day->{meals} = $meals;

$res = $valid->validate({
    _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/, bson => 'oid' },
    name => { type => 'string', required => 1, bson=>'huh?' },
    user => { type => 'string', required => 1 },
    not_required => { type => 'string' },
    day => { type => 'date', required => 1 },
    created => { type => 'datetime' },
    modified => { type => 'datetime' },
    meals => { type => ['object'], schema => 'Meal' }
}, clone($day));
is(@$res, 0);

$day->{meals}[0]{public} = 0;
$res = $valid->validate({
    _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/, bson => 'oid' },
    name => { type => 'string', required => 1 },
    user => { type => 'string', required => 1 },
    not_required => { type => 'string' },
    day => { type => 'date', required => 1 },
    created => { type => 'datetime' },
    modified => { type => 'datetime' },
    meals => { type => ['object'], schema => 'Meal' }
}, clone($day));
is(@$res, 0);

$day->{meals}[0]{public} = undef;
$res = $valid->validate({
    _id => { type => 'string', match => qr/^[[:xdigit:]]{24}$/, bson => 'oid' },
    name => { type => 'string', required => 1 },
    user => { type => 'string', required => 1 },
    not_required => { type => 'string' },
    day => { type => 'date', required => 1 },
    created => { type => 'datetime' },
    modified => { type => 'datetime' },
    meals => { type => ['object'], schema => 'Meal' }
}, clone($day));
is(@$res, 1);
is($res->[0], q!Not a "boolean" in public - !);

done_testing();


