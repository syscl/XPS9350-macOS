#!/bin/sh

#  umnt
#
#  (c) 2018 syscl
#
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
OFF="\033[m"

diskutil list
printf "Enter EFI's IDENTIFIER to unmount, e.g. ${RED}disk0s1${OFF}"
read -p ": " targetEFI
diskutil umount ${targetEFI}

exit 0
