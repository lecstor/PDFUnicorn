use Test::More;
use utf8;

use_ok PDFUnicorn::Template::Alloy;

my $alloy = PDFUnicorn::Template::Alloy->new;

ok $alloy, 'got alloy instance';

my $res = $alloy->render("<doc>{{ epoch(ts) }}", { ts => 1391461956 });
is $res, '<doc>Feb 3, 2014', 'ok floating';

$res = $alloy->render("<doc>{{ epoch('1391461956', tz => 'Australia/Brisbane') }}", {});
is $res, '<doc>Feb 4, 2014', 'ok Brisbane';

$res = $alloy->render("<doc>{{ epoch('1391461956', tz => '+1000') }}", {});
is $res, '<doc>Feb 4, 2014', 'ok +1000';

$res = $alloy->render("<doc>{{ epoch('1391461956', { \"tz\": \"+1100\"}) }}", {});
is $res, '<doc>Feb 4, 2014', 'ok json tz';

$res = $alloy->render("<doc>{{ epoch(ts, strf => '%c', locale => 'fr') }}", { ts => 1391461956 });
is $res, '<doc>3 févr. 2014 21:12:36', 'ok default locale fr';

$res = $alloy->render("<doc>{{ epoch(ts, locale => 'fr') }}", { ts => 1391461956 });
is $res, '<doc>3 févr. 2014', 'ok locale fr';


my $template1 = <<_EOP_;
{{ BLOCK block1 }}block{{ END }}
{{ INCLUDE block1 }}
_EOP_

my $template2 = <<_EOP_;
{{ INCLUDE block1 }}
_EOP_

ok eval{ $alloy->render(\$template1, {}); };
ok ! eval{ $alloy->render(\$template2, {}); };
ok eval{ $alloy->render(\$template1, {}); };

done_testing();
