# -*- mode: perl -*-
#
# $Id: 06.t,v 1.1 1999/10/24 13:30:25 tai Exp $
#

use Test;
use Safe;
use Text::SimpleTemplate;

BEGIN { plan tests => 1 }

$tmpl = new Text::SimpleTemplate;
$tmpl->setq("TEXT", 'hello, world');

ok("hello, world",
   $tmpl->pack(q{<% $TEXT %>})->fill(PACKAGE => new Safe));

exit(0);
