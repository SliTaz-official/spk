#!/bin/sh
#
. /lib/libtaz.sh

newline
boldify "Checking: spk bc"
./spk bc
#boldify "Checking: spk-add bc"
#./spk-add bc bc --forced
#boldify "Checking: spk-rm bc"
#./spk-rm bc

# Check libspk.sh functions usage.
echo -n "$(boldify "Checking: libspk.sh functions")"
indent 34 "$(colorize $(grep "[a-z]() {" lib/libspk.sh | wc -l) 32)"
separator
grep "[a-z]() {" lib/libspk.sh | while read line
do
	func=`echo "$line" | cut -d '(' -f 1`
	echo -n "Checking: ${func}()"
	indent 34 "$(grep "$func" spk* | wc -l)"
done
separator
echo "Run slitaz-base-files testsuite.sh to check libpkg.sh"
newline
exit 0
