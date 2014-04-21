use Test::More;
use strict;
use warnings;

use_ok 'Template::Alloy';

my $t1 = <<"__EOP__";
[% BLOCK document_title %]bling[% END %]
[% INCLUDE document_title %]
__EOP__

my $t2 = <<__EOP__;
[% INCLUDE document_title %]
__EOP__

my $t3 = <<__EOP__;
[% BLOCK document_title %]blah[% END %]
[% PROCESS document_title %]
__EOP__

my $t4 = <<__EOP__;
[% PROCESS document_title %]
__EOP__

my $out;

my $alloy = Template::Alloy->new();
ok $alloy->process(\$t1, {}, \$out) || diag($alloy->error);
ok $alloy->process(\$t2, {}, \$out) || diag($alloy->error);
ok $alloy->process(\$t1, {}, \$out) || diag($alloy->error);

$alloy = Template::Alloy->new();
ok $alloy->process(\$t3, {}, \$out) || diag($alloy->error);
ok $alloy->process(\$t4, {}, \$out) || diag($alloy->error);
ok $alloy->process(\$t3, {}, \$out) || diag($alloy->error);

done_testing();
