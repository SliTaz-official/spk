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
receipt_info() {
	cat << EOT
$(gettext "Version    :") ${VERSION}${EXTRAVERSION}
$(gettext "Short desc :") $SHORT_DESC
$(gettext "Category   :") $CATEGORY
EOT
}

# Used by: list
count_installed() {
	count=$(ls $installed | wc -l)
	gettext "Installed packages"; echo ": $count"
}

# Used by: list
count_mirrored() {
	count=$(cat $pkgsmd5 | wc -l)
	gettext "Mirrored packages"; echo ": $count"
}
