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
mirrors="${root}${PKGS_DB}/mirrors"
installed="${root}${PKGS_DB}/installed"
pkgsdesc="${root}${PKGS_DB}/packages.desc"
pkgsmd5="${root}${PKGS_DB}/packages.$SUM"
pkgsequiv="${root}${PKGS_DB}/packages.equiv"
pkgsup="${root}${PKGS_DB}/packages.up"
blocked="${root}${PKGS_DB}/blocked.list"
activity="${root}${PKGS_DB}/activity"
logdir="${root}/var/log/spk"
extradb="${root}${PKGS_DB}/extra"
tmpdir="/tmp/spk/$RANDOM"

#
# Sanity checks
#

if [ ! -d "${root}${PKGS_DB}" ]; then
	gettext "Can't find DB:"; echo " ${root}${PKGS_DB}"
	exit 1
fi

if [ ! -d "${root}${extradb}" ]; then
	mkdir -p ${root}${extradb}
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

# Display package info from a packages.desc list
# Usage: read_pkgsdesc /path/to/packages.desc
read_pkgsdesc() {
	local list="$1"
	IFS="|"
	cat $list | while read package version desc category
	do
		if [ "$short" ]; then
			echo -n "$(colorize 32 "$package")"; indent 28 " $version"
		else
			newline
			gettext "Package    :"; colorize 32 " $package"
			gettext "Version    :"; echo "$version"
			gettext "Short desc :"; echo "$desc"
		fi
	done && unset IFS
}

# Extract receipt from tazpkg
# Parameters: result_dir package_file
extract_receipt() {
	local dir="$1"
	local file="$2"
	cd "$dir"
	{ cpio --quiet -i receipt > /dev/null 2>&1; } < $file
	cd - >/dev/null
}

# Extract files.list from tazpkg
# Parameters: result_dir package_file
extract_fileslist() {
	local dir="$1"
	local file="$2"
	cd "$dir"
	{ cpio --quiet -i files.list > /dev/null 2>&1; } < $file
	cd - >/dev/null
}

is_package_installed() {
	[ -f "$installed/$1/receipt" ]
}

# Used by: list
count_installed() {
	local count=$(ls $installed | wc -l)
	gettext "Installed     :"; echo " $count"
}

# Used by: list
count_mirrored() {
	[ -f "$pkgsmd5" ] || return
	local count=$(cat $pkgsmd5 | wc -l)
	gettext "Mirrored      :"; echo " $count"
}

# Check if package is on main or extra mirror.
mirrored_pkg() {
	local name=$1
	#local find=$(grep "^$name |" $pkgsdesc $extradb/*/*.desc 2>/dev/null)
	for desc in $(find $extradb $pkgsdesc -name packages.desc); do
		if grep -q "^$name |" $desc; then
			db=$(dirname $desc)
			mirrored=$(grep "^$name |" $desc)
			mirror=$(cat $db/mirror)
			break
		fi
	done
}

# Check if the download was sane
check_download() {
	debug "check_download: $file"
	if ! tail -c 2k $file | fgrep -q 00000000TRAILER; then
		gettext "Continuing download of:"; echo " $file"
		download "$file" $mirror
	fi
	# Check that the package has the correct checksum
	local msum=$(fgrep "  $package_full" $pkgsmd5)
	local sum=$($CHECKSUM $file)
	debug "mirror $SUM : $msum"
	debug "local $SUM  : $sum"
	if [ "$sum" != "$msum" ]; then
		rm -f $file && download "$file" $mirror
	fi
}

# Download a file trying all mirrors
# Usage: file [url|path]
#
# Priority to extra is done by mirrored_pkg wich try first to find the
# packages in extra mirror, then on official.
#
download() {
	local file=$1
	local uri="${2%/}"
	local pwd=$(pwd)
	[ "$quiet" ] && local quiet="-q"
	[ "$cache" ] && local pwd=$CACHE_DIR
	[ "$get" ] || local pwd=$CACHE_DIR
	[ "$forced" ] && rm -f $pwd/$file
	debug "download file: $file"
	debug "DB: $db"
	# Local mirror ? End by cd to cache, we may be installind. If --get
	# was used we dl/copy in the current dir.
	if [ -f "$uri/$file" ]; then
		[ "$verbose" ] && echo "URI: $uri/"
		gettext "Using local mirror:"; boldify " $file"
		[ "$verbose" ] && (gettext "Copying file to:"; colorize 34 " $pwd")
		cp -f $uri/$file $pwd
		cd $pwd && return 0
	fi
	# In cache ? Root can use --cache to set destdir.
	if [ -f "$CACHE_DIR/$file" ]; then
		gettext "Using cache:"; colorize 34 " ${file%.tazpkg}"
		return 0
	else
		[ "$verbose" ] && echo "URL: $uri/"
		if [ "$db" == "$PKGS_DB" ]; then
			gettext "Using official mirror:"
		else
			gettext "Using extra mirror:"
		fi
		boldify " $file"
		[ "$verbose" ] && (gettext "Destination:"; colorize 34 " $pwd")
		if [ -f "$pwd/$file" ]; then
			echo "File exist: $pwd/$file" && return 0
		fi
		# TODO: be a spider with wget -s to check if package is on mirror,
		# if not try all official mirrors ?
		wget $quiet -c $uri/$file -O $CACHE_DIR/$file
		cd $CACHE_DIR && check_download
	fi
	# Be sure the file was fetched.
	if [ ! -f "$pwd/$file" ] || [ ! -f "$CACHE_DIR/$file" ]; then
		gettext "ERROR: Missing file:"; colorize 31 " $file"
		newline && exit 1
	fi
}

# Extract .tazpkg cpio archive into a directory.
# Parameters: package_file results_directory
extract_package() {
	local package_file=$1
	local target_dir=$2

	# Validate the file
	#check_valid_tazpkg $package_file

	# Find the package name
	local package_name=$(package_name $package_file)

	# Create destination directory and copy package
	local dest_dir=$(pwd)/$package_name
	[ -n "$target_dir" ] && dest_dir=$target_dir/$package_name
	mkdir -p $dest_dir
	cp $package_file $dest_dir

	cd $dest_dir
	size=$(du -sh $package_file | awk '{print $1}')
	echo -n $(gettext "Extracting archive"): $size
	cpio -idm --quiet < ${package_file##*/}
	rm -f ${package_file##*/}
	unlzma -c fs.cpio.lzma | cpio -idm --quiet
	rm fs.cpio.lzma
	status
	cd - > /dev/null
}

# Unser var set by mirrored_pkg
unset_mirrored() {
	unset mirrored mirror db pwd
}

# Return the full package name, search in all packages.desc and break when
# first occurance is found: Usage: full_package pkgname
full_package() {
	for desc in $(find $extradb $pkgsdesc -name packages.desc); do
		local line="$(grep "^$1 |" $desc)"
		if grep -q "^$1 |" $desc; then
			IFS="|"
			echo $line | busybox awk '{print $1 "-" $2 ".tazpkg"}'
			unset IFS && break
		fi
	done
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
	for i in $(grep -hs "^$1=" $pkgsequiv $extradb/*/*.equiv | sed "s/^$1=//")
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

	gettext "Missing dependencies:"; echo " $(colorize 34 "$deps")"

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

# Exec functions directly for developement purpose.
case $1 in
	*_*) func=$1 && shift && $func $@ ;;
esac
