# -*- mode: perl -*-
#
# $Id$
#

use Test;
use Text::SimpleTemplate;

BEGIN { plan tests => 1 }

$tmpl = new Text::SimpleTemplate;
$tmpl->pack(<<'EOF');
\<% <% my $text; for (0..9) { $text .= $_; } "\<% $text \%>"; %>
EOF

ok(1);
#ok("<% <% 0123456789 %>\n", $tmpl->fill);

exit(0);
