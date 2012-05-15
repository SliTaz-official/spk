#!/bin/sh
#
# Libspk - The Spk base function and internal variables used by almost all
# spk-tools. Read the README before adding or modifing any code in spk!
#
# Copyright (C) SliTaz GNU/Linux - BSD License
# Author: See AUTHORS files
#
. /lib/libtaz.sh
. /usr/lib/slitaz/libpkg.sh
. /etc/slitaz/slitaz.conf

# Internal variables.
# We should have ${root}/$PKGS_DB ???
mirrorurl="$PKGS_DB/mirror"
installed="$PKGS_DB/installed"
pkgsdesc="$PKGS_DB/packages.desc"
pkgsmd5="$PKGS_DB/packages.md5"
# ????do we need packages.equiv????
blocked="$PKGS_DB/blocked-packages.list"
activity="$PKGS_DB/activity"

#
# Functions

# Display receipt information. Expects a receipt to be sourced
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
	pushd "$dir" > /dev/null
	{ cpio --quiet -i receipt > /dev/null 2>&1; } < $file
	popd > /dev/null
}

# Used by: list
count_installed() {
	local count=$(ls ${root}${installed} | wc -l)
	gettext "Installed packages"; echo ": $count"
}

# Used by: list
count_mirrored() {
	local count=$(cat $pkgsmd5 | wc -l)
	gettext "Mirrored packages"; echo ": $count"
}

is_package_mirrored() {
	local name=$1
	local occurance=$(cat $pkgsdesc | grep "$name ")
	[ -n "$occurance" ]
}

# Download a file trying all mirrors
# Parameters: package/file
download() {
	local package=$1
	local mirror="$(cat $mirrorurl)"
	case "$package" in
		*.tazpkg)
			echo "${mirror%/}/$package"
			wget -c ${mirror%/}/$package ;;
	esac
}

# Assume package_name is valid
# There may be a more efficient way to do this...
full_package() {
	local name=$1
	local occurance=$(cat $pkgsdesc | grep "$name ")
	local count=0
	for i in $(echo $occurance | tr "|" "\n"); do
		if [ $count -eq 1 ]; then
			echo $name-$i && return
		fi
		count=$(($count+1))
	done
}

# Check if a package is already installed.
# Parameters: package
check_for_installed_package() {
	local name="$1"
	if [ -d "${root}${installed}/$name" ]; then
		newline
		echo $name $(gettext "package is already installed.")
		exit 0
	fi
}

# get an already installed package from packages.equiv  TODO REDO!
equivalent_pkg() {
	for i in $(grep -hs "^$1=" ${root}${PKGS_DB}/packages.equiv \
		   ${root}${PKGS_DB}/undigest/*/packages.equiv | sed "s/^$1=//")
	do
		if echo $i | fgrep -q : ; then
			# format 'alternative:newname'
			# if alternative is installed then substitute newname
			if [ -f ${root}${installed}/${i%:*}/receipt ]; then
				# substitute package dependancy
				echo ${i#*:}
				return
			fi
		else
			# if alternative is installed then nothing to install
			if [ -f ${root}${installed}/$i/receipt ]; then
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

	# Calculate missing dependencies
	for pkgorg in $depends; do
		local pkg=$(equivalent_pkg $pkgorg)
		if [ ! -d "${root}${installed}/$pkg" ]; then
			gettext "Missing: \$pkg"; newline
			deps=$(($deps+1))
		elif [ ! -f "${root}${installed}/$pkg/receipt" ]; then
			gettext "WARNING Dependency loop between \$package and \$pkg."; newline
		fi
	done
	if [ $deps -gt 0 ]; then
		echo $deps $(gettext "missing package(s) to install.")
	fi

	gettext "\$deps missing package(s) to install."; newline

	# Return true if missing deps
	[ "$deps" != "0" ]
}

grepesc() {
	sed 's/\[/\\[/g'
}

