# -*- mode: perl -*-
#
# $Id: 05.t,v 1.1 1999/10/24 13:30:25 tai Exp $
#

use Test;
use Text::SimpleTemplate;

BEGIN { plan tests => 1 }

$tmpl = new Text::SimpleTemplate;

ok($tmpl->load("/etc/group")->fill, `cat /etc/group`);

exit(0);
