#!/usr/bin/perl
#
# $Id: benchmark.pl,v 1.1 1999/10/13 15:02:54 tai Exp $
#
# Simple script to compare speed of Text::Template and this module.
#

use Benchmark;
use Text::Template;
use Text::SimpleTemplate;

$text = <<'EOF';
name: { $name }
type: { $type }
EOF

$text = $text x 2048;
$name = 'foobar';
$type = 'string';

timethese(10, {
    'old' => \&oldfunc,
    'new' => \&newfunc,
});

exit(0);

sub oldfunc {
    $tmpl = new Text::Template(TYPE => 'STRING', SOURCE => $text);
    $tmpl->fill_in(DELIMITERS => [qw({ })]);
}

sub newfunc {
    $tmpl = new Text::SimpleTemplate;
    $tmpl->pack($text, LR_CHAR => [qw({ })])->fill;
}
