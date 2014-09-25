#!/bin/sh

cat header.inc

VER="2014.0 RC3.5"

echo "<h1>Tools List $VER </h1>"
echo "<table>"
echo "<thead><tr><th><strong>TYPE</strong></th><th><strong>APP</strong></th><th><strong>VERSION</strong></th><th><strong>DESCRIPTION</strong></th></tr></thead>"

MYFR='\<tr\>
	\<td\><category>\</td\>
	\<td\>\<a href="<homepage>"\><name>\</a\>\</td\>
	\<td\><installedversions:VERSION>\</td\>
	\<td\><description>\</td\>
\</tr\>\n'
EIX_LIMIT=0 HOME=/tmp eix -I --pure-packages --format "$MYFR"
echo "</table>"

cat footer.inc
