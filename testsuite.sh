#!/bin/sh
#
. /lib/libtaz.sh

#boldify "Checking: spk-add"
#./spk-add bc bc --forced
#boldify "Checking: spk-rm"
#./spk-rm bc

echo -n "$(boldify "Checking: libspk.sh functions")"
indent 34 "$(colorize $(grep "[a-z]() {" lib/libspk.sh | wc -l) 32)"

grep "[a-z]() {" lib/libspk.sh | while read line
do
	func=`echo "$line" | cut -d '(' -f 1`
	echo -n "Checking: ${func}()"
	indent 34 "$(grep "$func" spk* | wc -l)"
done
exit 0
