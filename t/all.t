# -*- mode: perl -*-
#
# $Id: all.t,v 1.2 1999/10/13 15:06:56 tai Exp $
#
# A simple test script. Run it with 'make test' or 'perl test.pl'.
#

BEGIN { $| = 1; print "1..8\n"; }

use Safe;
use Text::SimpleTemplate;

package EmptyClass;

sub new { bless {}, shift; }

package main;

##
&test(1, $tmpl = new Text::SimpleTemplate);

##
$tmpl->setq("TEXT", 'hello, world');

## default
$text = $tmpl->pack('<% $TEXT %>')->fill;
&test(2, $text eq 'hello, world');

## user-set package
$text = $tmpl->pack('<% $TEXT %>')->fill(PACKAGE => 'Foo');
&test(3, $text eq 'hello, world');

## user-set delimiter
$text = $tmpl->pack('{ $TEXT }', LR_CHAR => [qw({ })])->fill;
&test(4, $text eq 'hello, world');

## user-set delimiter + user-set package
$text = $tmpl->pack('{ $TEXT }', LR_CHAR => [qw({ })])->fill(PACKAGE => 'Bar');
&test(5, $text eq 'hello, world');

## see if it works with Safe module
$text = $tmpl->pack('<% $TEXT %>')->fill(PACKAGE => new Safe);
&test(6, $text eq 'hello, world');

## see if it works with other modules (! Safe.pm)
$text = $tmpl->pack('<% $TEXT %>')->fill(PACKAGE => new EmptyClass);
&test(7, $text eq 'hello, world');

## see if it doesn't change anything
if (-e "/etc/group") {
    &test(8, $tmpl->load("/etc/group")->fill eq `cat /etc/group`);
}

exit(0);

sub test {
    my $id = shift;
    my $op = shift;

    print $op ? "ok $id\n" : "not ok $id\n";
}
