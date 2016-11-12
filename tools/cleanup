#!/bin/sh

#  cleanUp.sh
#  
#
#  Created by syscl/lighting/Yating Zhou on 16/2/10.
#

#================================= GLOBAL VARS ==================================

#
# The script expects '0.5' but non-US localizations use '0,5' so we export
# LC_NUMERIC here (for the duration of the deploy.sh) to prevent errors.
#
export LC_NUMERIC="en_US.UTF-8"

#
# Prevent non-printable/control characters.
#
unset GREP_OPTIONS
unset GREP_COLORS
unset GREP_COLOR

#
# Display style setting.
#
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
OFF="\033[m"

#
# Located repository.
#
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd | sed "s|\/tools||g" )

#
# Path and filename setup.
#
decompile="${REPO}/DSDT/raw/"
precompile="${REPO}/DSDT/precompile/"
compile="${REPO}/DSDT/compile/"
tools="${REPO}/tools/"
raw="${REPO}/DSDT/raw"
prepare="${REPO}/DSDT/prepare"

#==================================== START =====================================

rm -rf ${precompile} ${compile}
rm -rf ./Kexts/audio/AppleHDA_ALC668.kext
rm ${raw}/*.dsl
rm ${raw}/*.aml

#================================================================================

exit 0