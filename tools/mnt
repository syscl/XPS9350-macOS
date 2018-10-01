#!/bin/sh

#  mnt
#
#  (c) 2018 syscl
#
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
OFF="\033[m"
#
# On macOS 10.14 Mojave, we have to be a sudoer
# to mount the EFI partition
#
let requireRootMinVer=14
diskutil list
printf "Enter EFI's IDENTIFIER, e.g. ${RED}disk0s1${OFF}"
read -p ": " targetEFI
# get system version
gProductVer="$(sw_vers -productVersion)"
gMINOR_VER=${gProductVer:3:2}
if [ $gMINOR_VER -ge $requireRootMinVer ]; then
    # 10.14+
    sudo diskutil mount ${targetEFI}
else
    diskutil mount ${targetEFI}
fi

exit 0
