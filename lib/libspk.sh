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
mirrorurl="${root}${PKGS_DB}/mirror"
installed="${root}${PKGS_DB}/installed"
pkgsdesc="${root}${PKGS_DB}/packages.desc"
pkgsmd5="${root}${PKGS_DB}/packages.$SUM"
blocked="${root}${PKGS_DB}/blocked.list"
activity="${root}${PKGS_DB}/activity"
logdir="${root}/var/log/spk"

#
# Sanity checks
#

if [ ! -d "${root}${PKGS_DB}" ]; then
	gettext "Can't find DB:"; echo " ${root}${PKGS_DB}"
	exit 1
fi

#
# Functions
#

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
	debug "extract_receipt $1 $2"
	cd "$dir"
	{ cpio --quiet -i receipt > /dev/null 2>&1; } < $file
	cd - >/dev/null
}

# Used by: list
count_installed() {
	local count=$(ls $installed | wc -l)
	gettext "Installed  :"; echo " $count"
}

# Used by: list
count_mirrored() {
	local count=$(cat $pkgsmd5 | wc -l)
	gettext "Mirrored   :"; echo " $count"
}

is_package_mirrored() {
	local name=$1
	local occurance=$(fgrep "$name |" $pkgsdesc)
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
	if [ ! -f "$package" ]; then
		gettext "ERROR: Missing package $package"; newline
		newline && exit 1
	fi
}

# Assume package name is valid
full_package() {
	IFS="|"
	local line="$(grep "^$1 |" $pkgsdesc)"
	echo $line | busybox awk '{print $1 "-" $2}'
	unset IFS
}

# Check if a package is already installed.
# Usage: check_installed package
check_installed() {
	local name="$1"
	if [ -d "$installed/$name" ]; then
		echo $(boldify "$name") $(gettext "package is already installed")
		[ "$forced" ] || rm -rf $tmpdir
		continue
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

	# Calculate missing dependencies
	for pkgorg in $depends; do
		local pkg=$(equivalent_pkg $pkgorg)
		if [ ! -d "$installed/$pkg" ]; then
			gettext "Missing:"; echo " $pkg"
			deps=$(($deps+1))
		elif [ ! -f "$installed/$pkg/receipt" ]; then
			gettext "WARNING: Dependency loop between:"; newline
			echo "  $package --> $pkg"
		fi
	done

	gettext "Missing dependencies:"; echo " $(colorize "$deps" 34)"

	# Return true if missing deps
	[ "$deps" != "0" ]
}

grepesc() {
	sed 's/\[/\\[/g'
}

# Check for ELF file
is_elf() {
	[ "$(dd if=$1 bs=1 skip=1 count=3 2> /dev/null)" = "ELF" ]
}
