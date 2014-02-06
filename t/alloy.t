use Test::More;
use utf8;

use_ok PDFUnicorn::Template::Alloy;

my $alloy = PDFUnicorn::Template::Alloy->new;

ok $alloy, 'got alloy instance';

my $res = $alloy->render("[% epoch(ts) %]", { ts => 1391461956 });
is $res, 'Feb 3, 2014', 'ok floating';

$res = $alloy->render("[% epoch('1391461956', tz => 'Australia/Brisbane') %]", {});
is $res, 'Feb 4, 2014', 'ok Brisbane';

$res = $alloy->render("[% epoch('1391461956', tz => '+1000') %]", {});
is $res, 'Feb 4, 2014', 'ok +1000';

$res = $alloy->render("[% epoch('1391461956', { \"tz\": \"+1100\"}) %]", {});
is $res, 'Feb 4, 2014', 'ok json tz';

$res = $alloy->render("[% epoch(ts, strf => '%c', locale => 'fr') %]", { ts => 1391461956 });
is $res, '3 févr. 2014 21:12:36', 'ok default locale fr';

$res = $alloy->render("[% epoch(ts, locale => 'fr') %]", { ts => 1391461956 });
is $res, '3 févr. 2014', 'ok locale fr';

done_testing();
