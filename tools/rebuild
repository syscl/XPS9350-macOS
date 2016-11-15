#!/bin/sh

#  rebuild.sh
#  
#
#  Created by syscl/lighting/Yating Zhou on 16/4/29.
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
# Get user id
#
let gID=$(id -u)

#
# Located repository.
#
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#
# Define variables.
#
# Gvariables stands for getting datas from OS X.
#
gProductVer="$(sw_vers -productVersion)"
gOSVer=${gProductVer:0:5}
gMINOR_VER=${gProductVer:3:2}

#
# Set delimitation OS ver
#
let gDelimitation_OSVer=12

#
#--------------------------------------------------------------------------------
#

function _PRINT_MSG()
{
    local message=$1

    case "$message" in
      OK*    ) local message=$(echo $message | sed -e 's/.*OK://')
               echo "[  ${GREEN}OK${OFF}  ] ${message}."
               ;;

      FAILED*) local message=$(echo $message | sed -e 's/.*://')
               echo "[${RED}FAILED${OFF}] ${message}."
               ;;

      ---*   ) local message=$(echo $message | sed -e 's/.*--->://')
               echo "[ ${GREEN}--->${OFF} ] ${message}"
               ;;

      NOTE*  ) local message=$(echo $message | sed -e 's/.*NOTE://')
               echo "[ ${RED}Note${OFF} ] ${message}."
               ;;

      *      ) echo "$message"
               ;;
    esac
}

#
#--------------------------------------------------------------------------------
#

function _tidy_exec()
{
    if [ $gDebug -eq 0 ];
      then
        #
        # Using debug mode to output all the details.
        #
        _PRINT_MSG "DEBUG: $2"
        $1
      else
        #
        # Make the output clear.
        #
        $1 >/tmp/report 2>&1 && RETURN_VAL=0 || RETURN_VAL=1

        if [ "${RETURN_VAL}" == 0 ];
          then
            _PRINT_MSG "OK: $2"
          else
            _PRINT_MSG "FAILED: $2"
            cat /tmp/report
        fi

        rm /tmp/report &> /dev/null
    fi
}

#
#--------------------------------------------------------------------------------
#

function rebuild_kernel_cache()
{
    if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
      then
        #
        # syscl: 10.12+: we need to first remove kernelcache and prelinked cache
        #
        sudo rm -rf /System/Library/Caches/com.apple.kext.caches/Startup/kernelcache
        sudo rm -rf /System/Library/PrelinkedKernels/prelinkedkernel
    fi
    #
    # Repair the permission & refresh kernelcache.
    #
    sudo touch /Library/Extensions && sudo touch /System/Library/Extensions && sudo kextcache -u /
}

#
#--------------------------------------------------------------------------------
#

function main()
{
    #
    # Get argument.
    #
    local gArgv=$(echo "$@" | tr '[:lower:]' '[:upper:]')
    if [[ $# -eq 1 && "$gArgv" == "-D" || "$gArgv" == "-DEBUG" ]];
      then
        #
        # Yes, we do need debug mode.
        #
        _PRINT_MSG "NOTE: Use ${BLUE}DEBUG${OFF} mode"
        gDebug=0
      else
        #
        # No, we need a clean output style.
        #
        gDebug=1
    fi

    _PRINT_MSG "--->: ${BLUE}Rebuilding kernel extensions cache...${OFF}"
    _tidy_exec "rebuild_kernel_cache" "Rebuild kernel cache"
}

#==================================== START =====================================

main "$@"

#================================================================================

exit ${RETURN_VAL}
