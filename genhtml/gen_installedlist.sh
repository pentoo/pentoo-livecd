#!/bin/sh

echo "<table>"
echo "<thead><tr><th><strong>TYPE</strong></th><th><strong>APP</strong></th><th><strong>VERSION</strong></th><th><strong>DESCRIPTION</strong></th></tr></thead>"

MYFR='\<tr\>
	\<td\><category>\</td\> 
	\<td\>\<a href="<homepage>"\><name>\</a\>\</td\>
	\<td\><installedversions:VERSION>\</td\>
	\<td\><description>\</td\>
\</tr\>\n'
eix -I --pure-packages --format "$MYFR"

echo "</table>"
