#!/bin/sh
#
# Libspk - The Spk base function and internal variables used my almost all
# spk-tools. Read the README before adding or modifing any code in spk!
#
# Copyright (C) SliTaz GNU/Linux - BSD License
# Author: See AUTHORS files
#
. /lib/libtaz.sh
. /usr/lib/slitaz/libpkg.sh
. /etc/slitaz/slitaz.conf

# Internal variables.
mirrorurl="$PKGS_DB/mirror"
installed="$PKGS_DB/installed"
pkgsdesc="$PKGS_DB/packages.desc"
pkgsmd5="$PKGS_DB/packages.md5"
blocked="$PKGS_DB/blocked-packages.list"

#
# Functions
#

# Display receipt information.
# Expects a reciept to be sourced
receipt_info() {
	cat << EOT
$(gettext "Version    :") ${VERSION}${EXTRAVERSION}
$(gettext "Short desc :") $SHORT_DESC
$(gettext "Category   :") $CATEGORY
EOT
}

# Extract receipt from tazpkg
# Parameters: result_dir package_file
extract_receipt() {
	local dir="$1"
	local file="$2"

	pushd "$dir"
	{ cpio --quiet -i receipt > /dev/null 2>&1; } < $file
	popd
}

# Used by: list
count_installed() {
	local count=$(ls $installed | wc -l)
	gettext "Installed packages"; echo ": $count"
}

# Used by: list
count_mirrored() {
	local count=$(cat $pkgsmd5 | wc -l)
	gettext "Mirrored packages"; echo ": $count"
}

# get an already installed package from packages.equiv
equivalent_pkg() {
	for i in $(grep -hs "^$1=" $PKGS_DB/packages.equiv \
		   $PKGS_DB/undigest/*/packages.equiv | sed "s/^$1=//")
	do
		if echo $i | fgrep -q : ; then
			# format 'alternative:newname'
			# if alternative is installed then substitute newname
			if [ -f $installed/${i%:*}/receipt ]; then
				# substitute package dependancy
				echo ${i#*:}
				return
			fi
		else
			# if alternative is installed then nothing to install
			if [ -f $installed/$i/receipt ]; then
				# substitute installed package
				echo $i
				return
			fi
		fi
	done
	# if not found in packages.equiv then no substitution
	echo $1
}

# Check for missing deps listed in a receipt packages.
# Parameters: package dependencies
missing_deps() {
	local package="$1"
	shift 1
	local depends="$@"
	
	local deps=0
	local missing
	
	#Calculate missing dependencies
	for pkgorg in $depends; do
		local pkg=$(equivalent_pkg $pkgorg)
		if [ ! -d "$installed/$pkg" ]; then
			gettext "Missing: \$pkg"; newline
			deps=$(($deps+1))
		elif [ ! -f "$installed/$pkg/receipt" ]; then
			gettext "WARNING Dependency loop between \$package and \$pkg."; newline
		fi
	done
	
	gettext "\$deps missing package(s) to install."; newline
	
	# Return true if missing deps
	[ "$deps" != "0" ]
}
