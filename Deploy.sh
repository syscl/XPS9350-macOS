#!/bin/sh

#
# (c) 2017-2018 syscl @ https://github.com/syscl
# Merge for Dell XPS 13 9350 (Skylake)
#

#================================= GLOBAL VARS ==================================

#
# The script expects '0.5' but non-US localizations use '0,5' so we export
# LC_NUMERIC here (for the duration of the deploy.sh) to prevent errors.
#
export LC_NUMERIC="en_US.UTF-8"
export MG_DEBUG=0

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
# Define two status: 0 - Success, Turn on,
#                    1 - Failure, Turn off
#
kBASHReturnSuccess=0
kBASHReturnFailure=1

#
# Located repository.
#
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#
# Path and filename setup
#
gESPMountPoint=""
decompile="${REPO}/DSDT/raw/"
precompile="${REPO}/DSDT/precompile/"
compile="${REPO}/DSDT/compile/"
tools="${REPO}/tools/"
raw="${REPO}/DSDT/raw"
prepare="${REPO}/DSDT/prepare"
config_plist=""
#gConfigBuffer=$(cat ${config_plist})
EFI_INFO="${REPO}/DSDT/EFIINFO"
gInstall_Repo="/usr/local/sbin/"
gFrom="${REPO}/tools"
gUSBSleepConfig="/tmp/com.syscl.externalfix.sleepwatcher.plist"
gUSBSleepScript="/tmp/sysclusbfix.sleep"
gUSBWakeScript="/tmp/sysclusbfix.wake"
gRTWlan_kext=$(ls /Library/Extensions | grep -i "Rtw" | sed 's/.kext//')
gRTWlan_Repo="/Library/Extensions"
to_Plist="/Library/LaunchDaemons/com.syscl.externalfix.sleepwatcher.plist"
to_shell_sleep="/etc/sysclusbfix.sleep"
to_shell_wake="/etc/sysclusbfix.wake"
gRT_Config="/Applications/Wireless Network Utility.app"/${gMAC_adr}rfoff.rtl
drivers64UEFI="${REPO}/CLOVER/drivers64UEFI"
t_drivers64UEFI=""
clover_tools="${REPO}/CLOVER/tools"
t_clover_tools=""

#
# Define variables.
#
# Gvariables stands for getting datas from OS X.
#
gArgv=""
gDebug=${kBASHReturnFailure}
gProductVer=""
target_website=""
target_website_status=""
RETURN_VAL=""
gEDID=""
gHorizontalRez_pr=""
gHorizontalRez_st=""
gHorizontalRez=""
gVerticalRez_pr=""
gVerticalRez_st=""
gVerticalRez=""
gSystemRez=""
gSystemHorizontalRez=""
gSystemVerticalRez=""
gPatchIOKit=${kBASHReturnSuccess}
gClover_ig_platform_id=""
target_ig_platform_id=""
gTriggerLE=${kBASHReturnFailure}
gProductVer="$(sw_vers -productVersion)"
gOSVer=${gProductVer:0:5}
gMINOR_VER=${gProductVer:3:2}
gBak_Time=$(date +%Y-%m-%d-h%H_%M_%S)
gBak_Dir="${REPO}/Backups/${gBak_Time}"
gStop_Bak=${kBASHReturnFailure}
gRecoveryHD=""
gRecoveryHD_DMG="/Volumes/Recovery HD/com.apple.recovery.boot/BaseSystem.dmg"
gTarget_rhd_Framework=""
gTarget_Framework_Repo=""
gBluetooth_Brand_String=""
gModelType=1    # 0 stands for non-Iris model, 1 stands for Iris model
#
# Add: Comment(string), Disabled(bool), Find(data), Name(string), Replace(data)
# Set: $comment       , false         , syscl     , $binary_name, syscl
#
gProperties_Name=(Comment Disabled Find Name Replace)
gProperties_Type=(string bool data string data)
#
# Kexts to patch
#
cLidWake=""
fLidWake=""
rLidWake=""
nLidWake=""
cIntelGraphicsFrameBuffer=""
fIntelGraphicsFrameBuffer=""
rIntelGraphicsFrameBuffer=""
nIntelGraphicsFrameBuffer=""
cHDMI=""
fHDMI=""
rHDMI=""
nHDMI=""
cHandoff=""
fHandoff=""
rHandoff=""
nHandoff=""
#
# Audio variables
#
gResources_xml_zlib=("layout1" "Platforms")
gExtensions_Repo=("/System/Library/Extensions" "/Library/Extensions")
gInjector_Repo="/tmp/AppleHDA_ALC256.kext"
gAppleHDA_Config="${gInjector_Repo}/Contents/Info.plist"
doCommands=("${REPO}/tools/iasl" "/usr/libexec/plistbuddy -c" "perl -p -e 's/(\d*\.\d*)/9\1/'")

#
# Set delimitation OS ver
#
let gDelimitation_OSVer=12

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
function contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

#
# Get Current OS ver
#
current_OSVer=`sw_vers -productVersion`
contains "${current_OSVer}" "10.12"
if [ "$?" -eq "0" ]; then
    isSierra=1 #true: MacOS Sierra
  else
    isSierra=0 #false: MacOS High Sierra
fi

#
# Define target website
#
target_website=https://github.com/syscl/XPS9350-macOS

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
    esac
}

#
#--------------------------------------------------------------------------------
#

function _update()
{
    #
    # Sync all files from https://github.com/syscl/XPS9350-macOS
    #
    # Check if github is available
    #
    local timeout=5

    #
    # Detect whether the website is available
    #
    _PRINT_MSG "--->: Updating files from ${BLUE}${target_website}...${OFF}"
    target_website_status=`curl -I -s --connect-timeout $timeout ${target_website} -w %{http_code}`
    if [[ `echo ${target_website_status} | grep -i "Status"` == *"OK"* && `echo ${target_website_status} | grep -i "Status"` == *"200"* ]]
      then
        cd ${REPO}
        git pull
      else
        _PRINT_MSG "NOTE: ${BLUE}${target_website}${OFF} is not ${RED}available${OFF} at this time, please link ${BLUE}${target_website}${OFF} again next time."
    fi
}

#
#--------------------------------------------------------------------------------
#

function _locate_rhd()
{
    #
    # Passing gRecoveryHD from ${targetEFI}
    #
    local gDisk_INF="$1"

    #
    # Example:
    #
    # disk0s3
    # ^^^^^
    diskutil list |grep -i "${gDisk_INF:0:5}" |grep -i "Recovery HD" |grep -i -o "disk[0-9]s[0-9]"
}

#
#--------------------------------------------------------------------------------
#

function _getESPMntPoint()
{
    local gESPIndentifier="$1"
    gESPMountPoint=$(diskutil info ${gESPIndentifier} |grep -i 'Mount Point' |grep -i -o "/.*")
}

#
#--------------------------------------------------------------------------------
#

function _setESPVariable()
{
    config_plist="${gESPMountPoint}/EFI/CLOVER/config.plist"
    t_drivers64UEFI="${gESPMountPoint}/EFI/CLOVER/drivers64UEFI"
    t_clover_tools="${gESPMountPoint}/EFI/CLOVER/tools"
}

#
#--------------------------------------------------------------------------------
#

function _touch()
{
    local target_file=$1

    if [ ! -d ${target_file} ];
      then
        _tidy_exec "mkdir -p ${target_file}" "Create ${target_file}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function patch_acpi()
{
    #
    # create a backup of current error-free DSDT
    #
    cp "${REPO}"/DSDT/raw/$1.dsl "${REPO}"/DSDT/raw/$1_backup.dsl
    #
    # apply the patch
    #
    if [ "$2" == "syscl" ];
      then
        "${REPO}"/tools/patchmatic "${REPO}"/DSDT/raw/$1.dsl "${REPO}"/DSDT/patches/$3.txt "${REPO}"/DSDT/raw/$1.dsl
      else
        "${REPO}"/tools/patchmatic "${REPO}"/DSDT/raw/$1.dsl "${REPO}"/DSDT/patches/$2/$3.txt "${REPO}"/DSDT/raw/$1.dsl
    fi
    #
    # check if patched DSDT has errors
    #
    "${REPO}"/tools/iasl -vr -p "${REPO}"/DSDT/raw/$1temp.aml "${REPO}"/DSDT/raw/$1.dsl
    if [ -e "${REPO}"/DSDT/raw/$1temp.aml ]
      then
        rm "${REPO}"/DSDT/raw/$1temp.aml
        rm "${REPO}"/DSDT/raw/$1_backup.dsl
      else
        _PRINT_MSG "NOTE: $3 was not applied as it was causing errors."
        rm "${REPO}"/DSDT/raw/$1.dsl
        mv "${REPO}"/DSDT/raw/$1_backup.dsl "${REPO}"/DSDT/raw/$1.dsl
    fi
}

function patch_acpi_force()
{
    #
    # apply the patch
    #
    if [ "$2" == "syscl" ];
      then
        "${REPO}"/tools/patchmatic "${REPO}"/DSDT/raw/$1.dsl "${REPO}"/DSDT/patches/$3.txt "${REPO}"/DSDT/raw/$1.dsl
      else
        "${REPO}"/tools/patchmatic "${REPO}"/DSDT/raw/$1.dsl "${REPO}"/DSDT/patches/$2/$3.txt "${REPO}"/DSDT/raw/$1.dsl
    fi
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
        $1 >/tmp/report 2>&1 && RETURN_VAL=${kBASHReturnSuccess} || RETURN_VAL=${kBASHReturnFailure}

        if [ "${RETURN_VAL}" == ${kBASHReturnSuccess} ];
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

function compile_table()
{
    "${REPO}"/tools/iasl -vr -p "${compile}"$1.aml "${precompile}"$1.dsl
}

#
#--------------------------------------------------------------------------------
#

function rebuild_kernel_cache()
{
    #
    # Repair the permission & refresh kernelcache.
    #
#    if [ $gTriggerLE -eq 0 ];
#      then
        #
        # Yes, we do touch /L*/E*.
        #
#        sudo touch /Library/Extensions
#    fi

    #
    # /S*/L*/E* must be touched to prevent some potential issues.
    #
#    sudo touch /System/Library/Extensions
#    sudo /bin/kill -1 `ps -ax | awk '{print $1" "$5}' | grep kextd | awk '{print $1}'`
#    sudo kextcache -u /
    sudo kextcache -i /
}

#
#--------------------------------------------------------------------------------
#

function rebuild_dyld_shared_cache()
{
    #
    # rebuild dyld_shared_cache to resolve display framework issues
    #
    sudo update_dyld_shared_cache -force
}

#
#--------------------------------------------------------------------------------
#

function install_audio()
{
    #
    # Remove previous AppleHDA_ALC256.kext & CodecCommander.kext
    # Note: don't use cp/mv directly, in macOS, you have to use rm then cp! syscl
    #
    for extensions in ${gExtensions_Repo[@]}
    do
      _del $extensions/AppleHDA_ALC256.kext
      _del $extensions/CodecCommander.kext
    done

    if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
      then
        #
        # 10.12+
        #
        _install_AppleHDA_Injector
    fi
}

#
#--------------------------------------------------------------------------------
#

function _install_AppleHDA_Injector()
{
    _del "${gInjector_Repo}"
    _del "${KEXT_DIR}/AppleALC.kext"
    #
    # Generate audio from current system.
    #
    _PRINT_MSG "--->: Generating AppleHDA injector..."
    cp -RX "${gExtensions_Repo[0]}/AppleHDA.kext" ${gInjector_Repo}
    rm -rf ${gInjector_Repo}/Contents/Resources/*
    _del ${gInjector_Repo}/Contents/PlugIns
    _del ${gInjector_Repo}/Contents/_CodeSignature
    _del ${gInjector_Repo}/Contents/MacOS/AppleHDA
    _del ${gInjector_Repo}/Contents/version.plist
    ln -s ${gExtensions_Repo[0]}/AppleHDA.kext/Contents/MacOS/AppleHDA ${gInjector_Repo}/Contents/MacOS/AppleHDA

    for zlib in "${gResources_xml_zlib[@]}"
    do
      _tidy_exec "cp "${REPO}/Kexts/audio/Resources/layout/${zlib}.xml.zlib" "${gInjector_Repo}/Contents/Resources/"" "Copy ${zlib}"
    done

    replace=`${doCommands[1]} "Print :NSHumanReadableCopyright" ${gAppleHDA_Config} | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
    ${doCommands[1]} "Set :NSHumanReadableCopyright '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleGetInfoString" ${gAppleHDA_Config} | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
    ${doCommands[1]} "Set :CFBundleGetInfoString '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleVersion" ${gAppleHDA_Config} | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
    ${doCommands[1]} "Set :CFBundleVersion '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleShortVersionString" ${gAppleHDA_Config} | perl -Xpi -e 's/(\d*\.\d*)/9\1/'`
    ${doCommands[1]} "Set :CFBundleShortVersionString '$replace'" ${gAppleHDA_Config}
    ${doCommands[1]} "Add ':HardwareConfigDriver_Temp' dict" ${gAppleHDA_Config}
    ${doCommands[1]} "Merge ${gExtensions_Repo[0]}/AppleHDA.kext/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" ${gAppleHDA_Config}
    ${doCommands[1]} "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':HardwareConfigDriver_Temp'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" ${gAppleHDA_Config}
    #
    # Cause high CPU percentage occupation, don't use this
    #
#    ${doCommands[1]} "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" ${gAppleHDA_Config}
#    ${doCommands[1]} "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" ${gAppleHDA_Config}
    ${doCommands[1]} "Merge ${REPO}/Kexts/audio/Resources/ahhcd.plist ':IOKitPersonalities:HDA Hardware Config Resource'" ${gAppleHDA_Config}
    _tidy_exec "sudo cp -RX "${gInjector_Repo}" "${gExtensions_Repo[0]}"" "Install AppleHDA_ALC256"
    _tidy_exec "sudo cp -RX "${REPO}/Kexts/audio/CodecCommander.kext" "${gExtensions_Repo[0]}"" "Fix headphone static issue"

    #
    # Gain all binary patches from config.
    #
    gClover_kexts_to_patch_data=$(awk '/<key>KextsToPatch<\/key>.*/,/<\/array>/' ${config_plist})

    #
    # Added Clover patch for ALC256 in Sierra
    #
    # Enable Realtek ALC256 1/5
    #
    cALC256_Stage1="Enable Realtek ALC256 1/5"
    fALC256_Stage1="6102EC10"
    rALC256_Stage1="00000000"
    nALC256_Stage1="AppleHDA"
    #
    # Enable Realtek ALC256 2/5
    #
    cALC256_Stage2="Enable Realtek ALC256 2/5"
    fALC256_Stage2="6202EC10"
    rALC256_Stage2="00000000"
    nALC256_Stage2="AppleHDA"
    #
    # Enable Realtek ALC256 3/5
    #
    cALC256_Stage3="Enable Realtek ALC256 3/5"
    fALC256_Stage3="8508EC10"
    rALC256_Stage3="00000000"
    nALC256_Stage3="AppleHDA"
    #
    # Enable Realtek ALC256 4/5
    #
    cALC256_Stage5="Enable Realtek ALC256 4/5"
    fALC256_Stage5="8419D411"
    rALC256_Stage5="5602EC10"
    nALC256_Stage5="AppleHDA"
    #
    # Enable Realtek ALC256 5/5
    #
    cALC256_Stage5="Enable Realtek ALC256 5/5"
    fALC256_Stage5="8319D411"
    rALC256_Stage5="00000000"
    nALC256_Stage5="AppleHDA"
    #
    # Now let's inject it.
    #
    cALC256Data=("$cALC256_Stage1" "$cALC256_Stage2" "$cALC256_Stage3" "$cALC256_Stage4" "$cALC256_Stage5")
    fALC256Data=("$fALC256_Stage1" "$fALC256_Stage2" "$fALC256_Stage3" "$fALC256_Stage4" "$fALC256_Stage5")
    rALC256Data=("$rALC256_Stage1" "$rALC256_Stage2" "$rALC256_Stage3" "$rALC256_Stage4" "$rALC256_Stage5")
    nALC256Data=("$nALC256_Stage1" "$nALC256_Stage2" "$nALC256_Stage3" "$nALC256_Stage4" "$nALC256_Stage5")
    for ((k=0; k<${#nALC256Data[@]}; ++k))
    do
      local gCmp_fString=$(_bin2base64 "$fALC256Data")
      local gCmp_rString=$(_bin2base64 "$rALC256Data")
      if [[ $gClover_kexts_to_patch_data != *"$gCmp_fString"* || $gClover_kexts_to_patch_data != *"$gCmp_rString"* ]];
        then
          #
          # No patch existed in config.plist, add patch for it:
          #
          _kext2patch "${cALC256Data[k]}" "${fALC256Data[k]}" "${rALC256Data[k]}" "${nALC256Data[k]}"
      fi
    done

    #
    # Trigger /L*/E* to rebuild
    #
    gTriggerLE=0
}

#
#--------------------------------------------------------------------------------
#

function _initIntel()
{
    if [[ `${doCommands[1]} "Print"  "${config_plist}"` == *"Intel = false"* ]];
      then
        ${doCommands[1]} "Set ':Graphics:Inject:Intel' true" "${config_plist}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _getEDID()
{
    #
    # dump kext load status
    #
    local gKextStatus=$(kextstat)
    #
    # Whether the Intel Graphics kernel extensions are loaded in cache?
    #
    if [[ ${gKextStatus} == *"AppleIntelSKLGraphicsFramebuffer"* && ${gKextStatus} == *"AppleIntelSKLGraphics"* ]];
      then
        #
        # Yes. Then we can directly assess EDID from ioreg.
        #
        # Get raw EDID.
        #
        gEDID=$(ioreg -lw0 | grep -i "IODisplayEDID" | sed -e 's/.*<//' -e 's/>//')

        #
        # Get native resolution(Rez) from $gEDID.
        #
        # Get horizontal resolution. Arrays start from 0.
        #
        # Examples:
        #
        # 00ffffffffffff004c2d240137314a4d0d1001036c221b782aaaa5a654549926145054bfef808180714f010101010101010101010101302a009851002a4030701300520e1100001e000000fd00384b1e510e000a202020202020000000fc0053796e634d61737465720a20
        #                                                                                                                     ^
        #                                                                                                                 ^^
        #                                                                                                                           ^
        #                                                                                                                       ^^
        gHorizontalRez_pr=${gEDID:116:1}
        gHorizontalRez_st=${gEDID:112:2}
        gHorizontalRez=$((0x$gHorizontalRez_pr$gHorizontalRez_st))
        #
        # Get vertical resolution. Actually, Vertical rez is no more needed in this scenario, but we just use this to make the
        # progress clear.
        #
        gVerticalRez_pr=${gEDID:122:1}
        gVerticalRez_st=${gEDID:118:2}
        gVerticalRez=$((0x$gVerticalRez_pr$gVerticalRez_st))
      else
        #
        # No, we cannot assess EDID from ioreg. But now the resolution of current display has been forced to the highest resolution as vendor designed.
        #
        gSystemRez=$(system_profiler SPDisplaysDataType | grep -i "Resolution" | sed -e 's/.*://')
        gSystemHorizontalRez=$(echo $gSystemRez | sed -e 's/x.*//')
        gSystemVerticalRez=$(echo $gSystemRez | sed -e 's/.*x//')
    fi

    #
    # Patch IOKit/CoreDisplay?
    #
    local gIntelGraphicsCardInfo=$(ioreg -lw0 |grep -i "Intel Iris Graphics" |sed -e "/[^<]*<\"/s///" -e "s/\"\>//")
    if [[ "${gIntelGraphicsCardInfo}" != *"Iris"* ]] && [[ $gHorizontalRez -gt 1920 || $gSystemHorizontalRez -gt 1920 ]];
      then
        #
        # Yes, we indeed require a patch to unlock the limitation of flash rate of IOKit to power up the QHD+/4K display under non-Iris version
        #
        # Note: the argument of gPatchIOKit is set to 0 as default if the examination of resolution fail, this argument can ensure all models being powered up.
        #
        gPatchIOKit=${kBASHReturnSuccess}
       else
        #
        # No, patch IOKit is not required, we won't touch IOKit/CoreDisplay (for a more clean system).
        #
        gPatchIOKit=${kBASHReturnFailure}
    fi
    #
    # Passing gPatchIOKit to gPatchRecoveryHD.
    #
    gPatchRecoveryHD=${gPatchIOKit}
}

#
#--------------------------------------------------------------------------------
#

function _unlock_pixel_clock()
{
    if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
      then
        #
        # 10.12+
        #
        gTarget_rhd_Framework="$gMountPoint/System/Library/Frameworks/CoreDisplay.framework/Versions/Current/CoreDisplay"
      else
        #
        # 10.12-
        #
        gTarget_rhd_Framework="$gMountPoint/System/Library/Frameworks/IOKit.framework/Versions/Current/IOKit"
    fi

    sudo perl -i.bak -pe 's|\xB8\x01\x00\x00\x00\xF6\xC1\x01\x0F\x85|\x33\xC0\x90\x90\x90\x90\x90\x90\x90\xE9|sg' ${gTarget_rhd_Framework}
    _tidy_exec "sudo codesign -f -s - ${gTarget_rhd_Framework}" "Patch and sign framework for Recovery HD"
}

#
#--------------------------------------------------------------------------------
#

function _hwpArgvChk()
{
    gRm_SSDT_pr=${kBASHReturnFailure}
    gCp_SSDT_pr=${kBASHReturnFailure}
    #
    # hwp enable is ready
    #
    local ghwpArgvChk=$(grep -i -A 1 "HWPEnable" ${config_plist})
    if [[ "${ghwpArgvChk}" == *"true"* ]]; then
        #
        # hwp is enable, disable old style power management
        #
        gRm_SSDT_pr=${kBASHReturnSuccess}
        gCp_SSDT_pr=${kBASHReturnSuccess}
    fi
}

#
#--------------------------------------------------------------------------------
#

function _setModelType()
{
    #
    # set model type
    #
    local gCPUInfo=$(sysctl machdep.cpu.brand_string |sed -e "/.*) /s///" -e "/ CPU.*/s///")
    if [[ ${gCPUInfo} == *"i7-6560U"* ]];
      then
        #
        # Iris version(i7-6560U)
        #
        _PRINT_MSG "NOTE: Your laptop is Iris version(${BLUE}${gCPUInfo}${OFF})"
        gModelType=1
      else
        #
        # Non-Iris version(i5-6200U, i7-6500U)
        #
        _PRINT_MSG "NOTE: Your laptop is non-Iris version(${BLUE}${gCPUInfo}${OFF})"
        gModelType=0
    fi
}


#
#--------------------------------------------------------------------------------
#

function _setPlatformId()
{
    if [ ${gModelType} == 1 ];
      then
        #
        # Iris version(i7-6560U)
        #
        target_ig_platform_id="0x19260004"
      else
        #
        # Non-Iris version(i5-6200U, i7-6500U)
        #
        target_ig_platform_id="0x19160000"
    fi

    gClover_ig_platform_id=$(awk '/<key>ig-platform-id<\/key>.*/,/<\/string>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g')

    #
    # Added ig-platform-id injection.
    #
    if [ -z $gClover_ig_platform_id ];
      then
        ${doCommands[1]} "Add ':Graphics:ig-platform-id' string" ${config_plist}
        ${doCommands[1]} "Set ':Graphics:ig-platform-id' $target_ig_platform_id" ${config_plist}
      else
        #
        # ig-platform-id existed, check ig-platform-id.
        #
        if [[ $gClover_ig_platform_id != $target_ig_platform_id ]];
          then
            #
            # Yes, we have to touch/modify the config.plist.
            #
            sed -ig "s/$gClover_ig_platform_id/$target_ig_platform_id/g" ${config_plist}
        fi
    fi
}

#
#--------------------------------------------------------------------------------
#

function _check_and_fix_config()
{
    #
    # Check if tinySSDT items are existed
    #
    local dCheck_SSDT=("SSDT-XPS13SKL" "SSDT-ARPT-RP05" "SSDT-XHC" "SSDT-PNLF" "SSDT-ALC256")
    local gSortedOrder=$(awk '/<key>SortedOrder<\/key>.*/,/<\/array>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g')
    local gSortedNumber=$(awk '/<key>SortedOrder<\/key>.*/,/<\/array>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g' | wc -l)
    for tinySSDT in "${dCheck_SSDT[@]}"
    do
      if [[ $gSortedOrder != *"${tinySSDT}"* ]]; then
          #
          # tinySSDT no found, insert it
          #
          ${doCommands[1]} "Add ':ACPI:SortedOrder:' string" ${config_plist}
          ${doCommands[1]} "Set ':ACPI:SortedOrder:$gSortedNumber' ${tinySSDT}.aml" ${config_plist}
      fi
      #
      # Index changed, increment by 1
      #
      ((gSortedNumber++))
    done

    #
    # Gain all binary patches from config.
    #
    gClover_kexts_to_patch_data=$(awk '/<key>KextsToPatch<\/key>.*/,/<\/array>/' ${config_plist})

    if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
      then
        if [ $isSierra -eq 1 ];
          then
          #
          # Repair the lid wake problem for 0x19260004 by syscl/lighting/Yating Zhou.
          #
          cLidWake="Enable lid wake for 0x19260004 credit syscl/lighting/Yating Zhou"
          fLidWake="0a0b0300 00070600 03000000 04000000"
          rLidWake="0f0b0300 00070600 03000000 04000000"
          nLidWake="AppleIntelSKLGraphicsFramebuffer"

          #
          # eDP, port 0000, 0x19160000 credit syscl
          #
          cIntelGraphicsFrameBuffer="eDP, port 0000, 0x19160000 credit syscl"
          fIntelGraphicsFrameBuffer="00000000 00000000 00000800 02000000 98040000"
          rIntelGraphicsFrameBuffer="00000000 00000000 00000800 00040000 98040000"
          nIntelGraphicsFrameBuffer="AppleIntelSKLGraphicsFramebuffer"

          #
          # Check if "BT4LE-Handoff-Hotspot" is in place of kextstopatch.
          #
          cHandoff="Enable BT4LE-Handoff-Hotspot"
          fHandoff="4885ff74 47488b07"
          rHandoff="41be0f00 0000eb44"
          nHandoff="IOBluetoothFamily"

          #
          # Now let's inject it.
          #
          cBinData=("$cLidWake" "$cIntelGraphicsFrameBuffer" "$cHandoff")
          fBinData=("$fLidWake" "$fIntelGraphicsFrameBuffer" "$fHandoff")
          rBinData=("$rLidWake" "$rIntelGraphicsFrameBuffer" "$rHandoff")
          nBinData=("$nLidWake" "$nIntelGraphicsFrameBuffer" "$nHandoff")

          for ((j=0; j<${#nBinData[@]}; ++j))
          do
            local gCmp_fString=$(_bin2base64 "$fBinData")
            local gCmp_rString=$(_bin2base64 "$rBinData")
            if [[ $gClover_kexts_to_patch_data != *"$gCmp_fString"* || $gClover_kexts_to_patch_data != *"$gCmp_rString"* ]];
              then
                #
                # No patch existed in config.plist, add patch for it:
                #
                _kext2patch "${cBinData[j]}" "${fBinData[j]}" "${rBinData[j]}" "${nBinData[j]}"
            fi
          done
        else
          #
          # 10.13 config.plist patches
          #
          local gHeaderFix=$(awk '/<key>FixHeaders<\/key>.*/,/<*\/>/' ${config_plist})
          if [[ $gHeaderFix != *"FixHeaders"* ]];
            then
              #
              # Add FixHeaders_20000000 to Clover (Needed to boot High Sierra)
              #
              ${doCommands[1]} "Add ':ACPI:DSDT:Fixes:FixHeaders' bool" "${config_plist}"
              ${doCommands[1]} "Set ':ACPI:DSDT:Fixes:FixHeaders' true" "${config_plist}"
          else
            if [[ $gHeaderFix == *"false"* ]];
              then
                ${doCommands[1]} "Set ':ACPI:DSDT:Fixes:FixHeaders' true" "${config_plist}"
            fi
          fi
        fi
    fi
    #
    # Gain boot argv.
    #
    local gBootArgv=$(awk '/<key>NoEarlyProgress<\/key>.*/,/<*\/>/' ${config_plist})

    if [[ $gBootArgv != *"NoEarlyProgress"* ]];
      then
        #
        # Add argv to prevent/remove "Welcome to Clover... Scan Entries" at early startup.
        #
        ${doCommands[1]} "Add ':Boot:NoEarlyProgress' bool" "${config_plist}"
        ${doCommands[1]} "Set ':Boot:NoEarlyProgress' true" "${config_plist}"
      else
        if [[ $gBootArgv == *"false"* ]];
          then
            ${doCommands[1]} "Set ':Boot:NoEarlyProgress' true" "${config_plist}"
        fi
    fi
}

#
#--------------------------------------------------------------------------------
#

function _kext2patch()
{
    local comment=$1
    local fBinaryEncode=$(_bin2base64 "$2")
    local rBinaryEncode=$(_bin2base64 "$3")
    local binary_name=$4

    local gProperties_Data=("$comment" "false" "syscl" "$binary_name" "syscl")
    index=$(awk '/<key>KextsToPatch<\/key>.*/,/<\/array>/' ${config_plist} | grep -i "Name" | wc -l)

    #
    # Inject dict with patch now.
    #
    ${doCommands[1]} "Add ':KernelAndKextPatches:KextsToPatch:$index' dict" ${config_plist}

    for ((i=0; i<${#gProperties_Name[@]}; ++i))
    do
      ${doCommands[1]} "Add ':KernelAndKextPatches:KextsToPatch:$index:${gProperties_Name[i]}' ${gProperties_Type[i]}" ${config_plist}
      ${doCommands[1]} "Set ':KernelAndKextPatches:KextsToPatch:$index:${gProperties_Name[i]}' ${gProperties_Data[i]}" ${config_plist}

      case "${gProperties_Name[i]}" in
        Find   ) sed -ig "s|c3lzY2w=|$fBinaryEncode|g" ${config_plist}
                 ;;
        Replace) sed -ig "s|c3lzY2w=|$rBinaryEncode|g" ${config_plist}
                 ;;
      esac
    done
}

#
#--------------------------------------------------------------------------------
#

function _bin2base64()
{
    echo $1 | xxd -r -p | base64
}

#
#--------------------------------------------------------------------------------
#

function _find_acpi()
{
    #
    # Search specification tables by syscl/Yating Zhou.
    #
    number=$(ls "${REPO}"/DSDT/raw/SSDT*.dsl | wc -l)

    #
    # Search DptfTa.
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "DptfTa" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          DptfTa=SSDT-${index}
      fi
    done

    #
    # Search SaSsdt.
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "SaSsdt" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          SaSsdt=SSDT-${index}
      fi
    done

    #
    # Search sensrhub
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "sensrhub" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          sensrhub=SSDT-${index}
      fi
    done

    #
    # Search FACP
    #
    FACP=FACP

    #
    # Tables to be eliminated: Ther_Rvp, CpuSsdt, Cpu0Cst, ApCst, Cpu0Hwp, ApHwp, HwpLvt
    #
    # Search sensrhub
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "Ther_Rvp" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          rmSSDT_0=SSDT-${index}
      fi
    done
    #
    # Search CpuSsdt
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "CpuSsdt" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          rmSSDT_1=SSDT-${index}
      fi
    done
    #
    # Search xh_rvp07
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "xh_rvp07" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ]; then
          rmSSDT_2=SSDT-${index}
      fi
    done
    gRm_SSDT_Tabl=("$rmSSDT_0" "$rmSSDT_1" "$rmSSDT_2")
}

#
#--------------------------------------------------------------------------------
#

function _fixReboot()
{
    _gRstValnAdr
    gRstAdrConf=$(awk '/<key>ResetAddress<\/key>.*/,/<\/string>/' ${config_plist} |egrep -o '(<string>.*</string>)' |sed -e 's/<\/*string>//g')
    if [ -z $gRstAdrConf ];
      then
        ${doCommands[1]} "Add ':ACPI:ResetAddress' string" ${config_plist}
    fi
    ${doCommands[1]} "Set ':ACPI:ResetAddress' $gResetAddress" ${config_plist}

    gRstValConf=$(awk '/<key>ResetAddress<\/key>.*/,/<\/string>/' ${config_plist} |egrep -o '(<string>.*</string>)' |sed -e 's/<\/*string>//g')
    if [ -z $gRstValConf ];
      then
        ${doCommands[1]} "Add ':ACPI:ResetValue' string" ${config_plist}
    fi
    ${doCommands[1]} "Set ':ACPI:ResetValue' $gResetValue" ${config_plist}
}

#
#--------------------------------------------------------------------------------
#

function _gRstValnAdr()
{
    local gTargetTabl="${decompile}/${FACP}.dsl"
    local tmpRstAdr=$(grep -i -B 2 "Value to cause reset" ${gTargetTabl} |grep -i "Address" |sed "/.*: /s///")
    #
    # you can use 4 instead of 2, but in XPS 13(SKL) that's it
    #
    gResetAddress=$(printf "0x${tmpRstAdr:(-2)}")
    local tmpRstVal=$(grep -i "Value to cause reset" ${gTargetTabl} |sed "/.*: /s///")
    gResetValue=$(printf "0x${tmpRstVal:(-2)}")
}

#
#--------------------------------------------------------------------------------
#

function _twhibernatemod()
{
    #
    # tweak hibernatemode for skylake/kabylake platforms
    #
    # note: hibernatemode on skylake platform behave unstable, and very likely to break all the data(nvme issue?)
    # thus, we better switch to a faster and better hibernatemode = 0
    #
    local gTarHibernateMode=0
    local gOrgHibernateMode=$(pmset -g |grep -i "hibernatemode" |sed 's|hibernatemode||')
    if [[ ${gOrgHibernateMode} != *"${gTarHibernateMode}"* ]]; then
        _tidy_exec "sudo pmset hibernatemode ${gTarHibernateMode}" "Change hibernatemode from ${gOrgHibernateMode} to ${gTarHibernateMode}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _tw_autopoweroff()
{
    #
    # disable autopoweroff on skylake/kabylake platforms
    #
    # setting hibernatemode = 0 isn't enough for us to prevent data corrupt
    # autopoweroff will still write data to disk (c) bozma88, ZombieTheBest
    #
    local gTarAutopoweroff=0
    local gOrigAutopoweroff=$(pmset -g |grep -v "autopoweroffdelay" | grep -i "autopoweroff" |sed 's|autopoweroff||')
    if [[ ${gOrigAutopoweroff} != *"${gTarAutopoweroff}"* ]]; then
        _tidy_exec "sudo pmset autopoweroff ${gTarAutopoweroff}" "Change autopoweroff from ${gOrigAutopoweroff} to ${gTarAutopoweroff}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _tw_standby()
{
    #
    # disable standby on skylake/kabylake platforms
    #
    local gTarStandby=0
    local gOrgStandby=$(pmset -g |grep -v 'standbydelay' |grep -i 'standby' |sed 's|standby||')
    if [[ ${gOrgStandby} != *"${gTarStandby}"* ]]; then
        _tidy_exec "sudo pmset -a standby ${gTarStandby}" "Change standby from ${gOrgStandby} to ${gTarStandby}"
    fi

}

#
#--------------------------------------------------------------------------------
#

function _update_clover()
{
    KEXT_DIR="${gESPMountPoint}/EFI/CLOVER/kexts/${gOSVer}"

    #
    # Updating kexts. NOTE: This progress will remove any previous kexts
    #
    _PRINT_MSG "--->: ${BLUE}Updating kexts...${OFF}"
    _tidy_exec "rm -rf ${KEXT_DIR}" "Remove pervious kexts in ${KEXT_DIR}"
    _tidy_exec "cp -R ./CLOVER/kexts/${gOSVer} ${gESPMountPoint}/EFI/CLOVER/kexts/" "Update kexts from ./CLOVER/kexts/${gOSVer}"
    _tidy_exec "cp -R ./Kexts/*.kext ${KEXT_DIR}/" "Update kexts from ./Kexts"
    if [[ ${gSelect_TouchPad_Drv} == 1 ]];
      then
        #
        # Use ApplePS2SmartTouchPad, remove VoodooPS2
        #
        _tidy_exec "rm -rf ${KEXT_DIR}/VoodooPS2Controller.kext" "Install ApplePS2SmartTouchPad"
      else
        #
        # Use VoodooI2C, remove ApplePS2SmartTouchPad, VoodooPS2Controller.kext
        #
        _tidy_exec "rm -rf ${KEXT_DIR}/ApplePS2SmartTouchPad.kext ${KEXT_DIR}/VoodooPS2Controller.kext" "Install VoodooI2C"
    fi

    #
    # Decide which BT kext to use.
    #
    gBluetooth_Brand_String=$(ioreg | grep -i 'BCM' | grep -i 'Apple' | sed -e 's/.*-o //' -e 's/@.*//')
    #
    # Install bluetooth drivers
    #
    # Decide which bluetooth driver to install
    #
    # I hate this way to deal with driver, but I will refine it later
    #
    _del ${KEXT_DIR}/BrcmPatchRAM2.kext
    _del ${KEXT_DIR}/BrcmFirmwareData.kext
    for extensions in ${gExtensions_Repo[@]}
    do
      _del $extensions/BrcmFirmwareData.kext
      _del $extensions/BrcmFirmwareRepo.kext
      _del $extensions/BrcmPatchRAM2.kext
    done
    _tidy_exec "sudo cp -RX ./Kexts/BrcmPatchRAM2.kext ${gExtensions_Repo[0]}" "Install BrcmPatchRAM2"
    _tidy_exec "sudo cp -RX ./Kexts/BrcmFirmwareRepo.kext ${gExtensions_Repo[0]}" "Install BrcmFirmwareRepo"

    #
    # gEFI.
    #
    drvEFI=("FSInject-64.efi" "HFSPlus.efi" "OsxAptioFix2Drv-64.efi" "DataHubDxe-64.efi")
    efiTOOL=("Shell.inf" "Shell32.efi" "Shell64.efi" "Shell64U.efi" "bdmesg-32.efi" "bdmesg.efi")

    #
    # Check if necessary to update Clover.
    #
    for filename in "${drvEFI[@]}"
    do
      _updfl "${t_drivers64UEFI}/${filename}" "${drivers64UEFI}/${filename}"
    done

    for filename in "${efiTOOL[@]}"
    do
      _updfl "${t_clover_tools}/${filename}" "${clover_tools}/${filename}"
    done

    #
    # Update CLOVERX64.efi
    #
    _updfl "${gESPMountPoint}/EFI/CLOVER/CLOVERX64.efi" "${REPO}/CLOVER/CLOVERX64.efi"
}

#
#--------------------------------------------------------------------------------
#

function _updfl()
{
    local gTargetf=$1
    local gSourcef=$2
    local gTargetHash=""
    local gSourceHash=""

    if [ -f ${gTargetf} ]; then
        gTargetHash=$(md5 -q $gTargetf)
    fi

    if [ -f ${gSourcef} ]; then
        gSourceHash=$(md5 -q $gSourcef)
    fi

    if [[ "${gTargetHash}" != "${gSourceHash}" ]]; then
        #
        # Update target file
        #
        _tidy_exec "cp ${gSourcef} ${gTargetf}" "Update ${gTargetf}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _update_thm()
{
    if [ -d "${gESPMountPoint}/EFI/CLOVER/themes/bootcamp" ];
      then
        if [[ `cat "${gESPMountPoint}/EFI/CLOVER/themes/bootcamp/theme.plist"` != *"syscl"* ]];
          then
            #
            # Yes we need to update themes.
            #
            _del "${gESPMountPoint}/EFI/CLOVER/themes/bootcamp"
            cp -R "${REPO}/CLOVER/themes/BootCamp" "${gESPMountPoint}/EFI/CLOVER/themes"
        fi
    fi
}

#
#--------------------------------------------------------------------------------
#

function _printUSBSleepConfig()
{
    _del ${gUSBSleepConfig}

    echo '<?xml version="1.0" encoding="UTF-8"?>'                                                                                                           > "$gUSBSleepConfig"
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'                                          >> "$gUSBSleepConfig"
    echo '<plist version="1.0">'                                                                                                                           >> "$gUSBSleepConfig"
    echo '<dict>'                                                                                                                                          >> "$gUSBSleepConfig"
    echo '	<key>KeepAlive</key>'                                                                                                                          >> "$gUSBSleepConfig"
    echo '	<true/>'                                                                                                                                       >> "$gUSBSleepConfig"
    echo '	<key>Label</key>'                                                                                                                              >> "$gUSBSleepConfig"
    echo '	<string>com.syscl.externalfix.sleepwatcher</string>'                                                                                           >> "$gUSBSleepConfig"
    echo '	<key>ProgramArguments</key>'                                                                                                                   >> "$gUSBSleepConfig"
    echo '	<array>'                                                                                                                                       >> "$gUSBSleepConfig"
    echo '		<string>/usr/local/sbin/sleepwatcher</string>'                                                                                             >> "$gUSBSleepConfig"
    echo '		<string>-V</string>'                                                                                                                       >> "$gUSBSleepConfig"
    echo '		<string>-s /etc/sysclusbfix.sleep</string>'                                                                                                >> "$gUSBSleepConfig"
    echo '		<string>-w /etc/sysclusbfix.wake</string>'                                                                                                 >> "$gUSBSleepConfig"
    echo '	</array>'                                                                                                                                      >> "$gUSBSleepConfig"
    echo '	<key>RunAtLoad</key>'                                                                                                                          >> "$gUSBSleepConfig"
    echo '	<true/>'                                                                                                                                       >> "$gUSBSleepConfig"
    echo '</dict>'                                                                                                                                         >> "$gUSBSleepConfig"
    echo '</plist>'                                                                                                                                        >> "$gUSBSleepConfig"
}

#
#--------------------------------------------------------------------------------
#

function _createUSB_Sleep_Script()
{
    #
    # Remove previous script.
    #
    _del ${gUSBSleepScript}

    echo '#!/bin/sh'                                                                                                                                         > "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# This script aims to unmount all external devices automatically before sleep.'                                                                   >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Without this procedure, various computers with OS X/Mac OS X(even on a real Mac) suffer from "Disk not ejected properly"'                       >> "$gUSBSleepScript"
    echo '# issue when there're external devices plugged-in. That's the reason why I created this script to fix this issue. (syscl/lighting/Yating Zhou)'   >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# All credit to Bernhard Baehr (bernhard.baehr@gmx.de), without his great sleepwatcher dameon, this fix will not be created.'                     >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Added unmount Disk for "OS X" (c) syscl/lighting/Yating Zhou.'                                                                                  >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo 'gMountPartition="/tmp/com.syscl.externalfix"'                                                                                                     >> "$gUSBSleepScript"
    echo 'gDisk=($(ls /dev/disk? |grep -i -o "disk[0-9]"))'                                                                                                  >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo 'for ((i=0; i<${#gDisk[@]}; ++i))'                                                                                                                 >> "$gUSBSleepScript"
    echo 'do'                                                                                                                                               >> "$gUSBSleepScript"
    echo '  gProtocol=$(diskutil info ${gDisk[i]} |grep -i "Protocol" |sed -e "s|Protocol:||" -e "s| ||g")'                                                 >> "$gUSBSleepScript"
    echo '  if [[ ${gProtocol} == *"USB"* ]];'                                                                                                              >> "$gUSBSleepScript"
    echo '    then'                                                                                                                                         >> "$gUSBSleepScript"
    echo '      gCurrent_Partitions=($(ls /dev/${gDisk[i]}s? |grep -o "disk[0-9]s[0-9]"))'                                                                  >> "$gUSBSleepScript"
    echo '      for ((k=0; k<${#gCurrent_Partitions[@]}; ++k))'                                                                                             >> "$gUSBSleepScript"
    echo '      do'                                                                                                                                         >> "$gUSBSleepScript"
    echo '        gConfirm_Mounted=$(diskutil info ${gCurrent_Partitions[k]} |grep -i 'Mounted' |sed -e "s| Mounted:||" -e "s| ||g")'                       >> "$gUSBSleepScript"
    echo '        if [[ ${gConfirm_Mounted} == *"Yes"* ]];'                                                                                                 >> "$gUSBSleepScript"
    echo '          then'                                                                                                                                   >> "$gUSBSleepScript"
    echo '            echo ${gCurrent_Partitions[k]} >> ${gMountPartition}'                                                                                 >> "$gUSBSleepScript"
    echo '        fi'                                                                                                                                       >> "$gUSBSleepScript"
    echo '      done'                                                                                                                                       >> "$gUSBSleepScript"
    echo '      diskutil eject ${gDisk[i]}'                                                                                                                 >> "$gUSBSleepScript"
    echo '  fi'                                                                                                                                             >> "$gUSBSleepScript"
    echo 'done'                                                                                                                                             >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    #
    # Add detection for RTLWlan USB
    #
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Fix RTLWlanUSB sleep problem credit B1anker & syscl/lighting/Yating Zhou. @PCBeta.'                                                             >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo "gRTWlan_kext=$(echo $gRTWlan_kext)"                                                                                                               >> "$gUSBSleepScript"
    echo 'gMAC_adr=$(ioreg -rc $gRTWlan_kext | sed -n "/IOMACAddress/ s/.*= <\(.*\)>.*/\1/ p")'                                                             >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo 'if [[ "$gMAC_adr" != 0 ]];'                                                                                                                       >> "$gUSBSleepScript"
    echo '  then'                                                                                                                                           >> "$gUSBSleepScript"
    echo '    gRT_Config="/Applications/Wireless Network Utility.app"/${gMAC_adr}rfoff.rtl'                                                                 >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo '    if [ ! -f $gRT_Config ];'                                                                                                                     >> "$gUSBSleepScript"
    echo '      then'                                                                                                                                       >> "$gUSBSleepScript"
    echo '        gRT_Config=$(ls "/Applications/Wireless Network Utility.app"/*rfoff.rtl)'                                                                 >> "$gUSBSleepScript"
    echo '    fi'                                                                                                                                           >> "$gUSBSleepScript"
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo "    osascript -e 'quit app \"Wireless Network Utility\"'"                                                                                         >> "$gUSBSleepScript"
    echo '    echo "1" > "$gRT_Config"'                                                                                                                     >> "$gUSBSleepScript"
    echo '    open "/Applications/Wireless Network Utility.app"'                                                                                            >> "$gUSBSleepScript"
    echo 'fi'                                                                                                                                               >> "$gUSBSleepScript"
    #
    # Added detect hibernate mode == 0 for XPS 13 93x0(Skylake/Kabylake)
    #
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Reset hibernate mode to 0 if hibernate mode has been changed by macOS'                                                                          >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo 'gTarHibernateMode=0'                                                                                                                              >> "$gUSBSleepScript"
    echo 'gOrgHibernateMode=$(pmset -g |grep -i "hibernatemode" |sed "s|hibernatemode||")'                                                                  >> "$gUSBSleepScript"
    echo 'if [[ ${gOrgHibernateMode} != *"${gTarHibernateMode}"* ]]; then'                                                                                  >> "$gUSBSleepScript"
    echo '    pmset hibernatemode ${gTarHibernateMode}'                                                                                                     >> "$gUSBSleepScript"
    echo '    gSleepImageSz=0'                                                                                                                              >> "$gUSBSleepScript"
    echo '    if [ -f /var/vm/sleepimage ]; then'                                                                                                           >> "$gUSBSleepScript"
    echo '        gSleepImageSz=$(stat -f'%z' /var/vm/sleepimage)'                                                                                          >> "$gUSBSleepScript"
    echo '    fi'                                                                                                                                           >> "$gUSBSleepScript"
    echo '    if [[ ${gSleepImageSz} != "0" ]]; then'                                                                                                       >> "$gUSBSleepScript"
    echo '        rm /var/vm/sleepimage'                                                                                                                    >> "$gUSBSleepScript"
    echo '    fi'                                                                                                                                           >> "$gUSBSleepScript"
    echo 'fi'                                                                                                                                               >> "$gUSBSleepScript"
    #
    # Added detect for autopoweroff == 0 for XPS 13 93x0(Skylake/Kabylake)
    #
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Reset autopoweroff to 0 if autopoweroff has been changed by macOS'                                                                              >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo 'gTarAutopoweroff=0'                                                                                                                               >> "$gUSBSleepScript"
    echo 'gOrigAutopoweroff=$(pmset -g |grep -v "autopoweroffdelay" | grep -i "autopoweroff" |sed "s|autopoweroff||")'                                      >> "$gUSBSleepScript"
    echo 'if [[ ${gOrigAutopoweroff} != *"${gTarAutopoweroff}"* ]]; then'                                                                                   >> "$gUSBSleepScript"
    echo '    pmset autopoweroff ${gTarAutopoweroff}'                                                                                                       >> "$gUSBSleepScript"
    echo 'fi'                                                                                                                                               >> "$gUSBSleepScript"
    #
    # Added detect for standby == 0 for XPS 13 93x0(Skylake/Kabylake)
    #
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo '# Reset standby to 0 if standby has been changed by macOS'                                                                                        >> "$gUSBSleepScript"
    echo '#'                                                                                                                                                >> "$gUSBSleepScript"
    echo 'gTarStandby=0'                                                                                                                                    >> "$gUSBSleepScript"
    echo 'gOrgStandby=$(pmset -g |grep -v "standbydelay" | grep -i "standby" |sed "s|standby||")'                                                           >> "$gUSBSleepScript"
    echo 'if [[ ${gOrgStandby} != *"${gTarStandby}"* ]]; then'                                                                                              >> "$gUSBSleepScript"
    echo '    pmset standby ${gTarStandby}'                                                                                                                 >> "$gUSBSleepScript"
    echo 'fi'                                                                                                                                               >> "$gUSBSleepScript"
}

#
#--------------------------------------------------------------------------------
#

function _RTLWlanU()
{
    _del ${gUSBWakeScript}
    _del "/etc/syscl.usbfix.wake"

    #
    # Add detection for RTLWlan USB
    #
    echo '#!/bin/sh'                                                                                                                                         > "$gUSBWakeScript"
    echo '#'                                                                                                                                                >> "$gUSBWakeScript"
    echo '# Added mount Disk for "OS X" (c) syscl/lighting/Yating Zhou.'                                                                                    >> "$gUSBWakeScript"
    echo '#'                                                                                                                                                >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo 'gMountPartition="/tmp/com.syscl.externalfix"'                                                                                                     >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo 'cat ${gMountPartition} |xargs -I {} diskutil mount {}'                                                                                            >> "$gUSBWakeScript"
    echo 'rm ${gMountPartition}'                                                                                                                            >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo '#'                                                                                                                                                >> "$gUSBWakeScript"
    echo '# Fix RTLWlanUSB sleep problem credit B1anker & syscl/lighting/Yating Zhou. @PCBeta.'                                                             >> "$gUSBWakeScript"
    echo '#'                                                                                                                                                >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo "gRTWlan_kext=$(echo $gRTWlan_kext)"                                                                                                               >> "$gUSBWakeScript"
    echo 'gMAC_adr=$(ioreg -rc $gRTWlan_kext | sed -n "/IOMACAddress/ s/.*= <\(.*\)>.*/\1/ p")'                                                             >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo 'if [[ "$gMAC_adr" != 0 ]];'                                                                                                                       >> "$gUSBWakeScript"
    echo '  then'                                                                                                                                           >> "$gUSBWakeScript"
    echo '    gRT_Config="/Applications/Wireless Network Utility.app"/${gMAC_adr}rfoff.rtl'                                                                 >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo '    if [ ! -f $gRT_Config ];'                                                                                                                     >> "$gUSBWakeScript"
    echo '      then'                                                                                                                                       >> "$gUSBWakeScript"
    echo '        gRT_Config=$(ls "/Applications/Wireless Network Utility.app"/*rfoff.rtl)'                                                                 >> "$gUSBWakeScript"
    echo '    fi'                                                                                                                                           >> "$gUSBWakeScript"
    echo ''                                                                                                                                                 >> "$gUSBWakeScript"
    echo "    osascript -e 'quit app \"Wireless Network Utility\"'"                                                                                         >> "$gUSBWakeScript"
    echo '    echo "0" > "$gRT_Config"'                                                                                                                     >> "$gUSBWakeScript"
    echo '    open "/Applications/Wireless Network Utility.app"'                                                                                            >> "$gUSBWakeScript"
    echo 'fi'                                                                                                                                               >> "$gUSBWakeScript"
}

#
#--------------------------------------------------------------------------------
#

function _fnd_RTW_Repo()
{
    if [ -z $gRTWlan_kext ];
      then
        #
        # RTWlan_kext is not in /Library/Extensions. Check /S*/L*/E*.
        #
        gRTWlan_kext=$(ls /System/Library/Extensions | grep -i "Rtw" | sed 's/.kext//')
        gRTWlan_Repo="/System/Library/Extensions"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _del()
{
    local target_file=$1

    if [ -d ${target_file} ];
      then
        _tidy_exec "sudo rm -R ${target_file}" "Remove ${target_file}"
      else
        if [ -f ${target_file} ];
          then
            _tidy_exec "sudo rm ${target_file}" "Remove ${target_file}"
        fi
    fi
}

#
#--------------------------------------------------------------------------------
#

function _fix_usb_ejected_improperly()
{
    #
    # Generate configuration file of sleepwatcher launch demon.
    #
    _tidy_exec "_printUSBSleepConfig" "Generate configuration file of sleepwatcher launch daemon"

    #
    # Find RTW place.
    #
    _fnd_RTW_Repo

    #
    # Generate script to unmount external devices before sleep (c) syscl/lighting/Yating Zhou.
    #
    _tidy_exec "_createUSB_Sleep_Script" "Generating script to unmount external devices before sleep (c) syscl/lighting/Yating Zhou"

    #
    # Generate script to load RTWlanUSB upon sleep.
    #
    _tidy_exec "_RTLWlanU" "Generate script to load RTWlanUSB upon sleep"

    #
    # Install sleepwatcher daemon.
    #
    _PRINT_MSG "--->: Installing external devices sleep patch..."
    sudo mkdir -p "${gInstall_Repo}"
    _tidy_exec "sudo cp "${gFrom}/sleepwatcher" "${gInstall_Repo}"" "Install sleepwatcher daemon"
    _tidy_exec "sudo cp "${gUSBSleepConfig}" "${to_Plist}"" "Install configuration of sleepwatcher daemon"
    _tidy_exec "sudo cp "${gUSBSleepScript}" "${to_shell_sleep}"" "Install sleep script"
    _tidy_exec "sudo cp "${gUSBWakeScript}" "${to_shell_wake}"" "Install wake script"
    _tidy_exec "sudo chmod 744 ${to_shell_sleep}" "Fix the permissions of ${to_shell_sleep}"
    _tidy_exec "sudo chmod 744 ${to_shell_wake}" "Fix the permissions of ${to_shell_wake}"
    _tidy_exec "sudo launchctl load ${to_Plist}" "Trigger startup service of syscl.usb.fix"

    #
    # Clean up.
    #
    _tidy_exec "rm $gConfig $gUSBSleepScript" "Clean up"
}

#
#--------------------------------------------------------------------------------
#

function _printBackupLOG()
{
    #
    # Examples:
    #
    # 2016-07-17-h01_43_14
    # ^^^^ ^^ ^^
    #             ^^ ^^ ^^
    local gDAY="${gBak_Time:5:2}/${gBak_Time:8:2}/${gBak_Time:0:4}"
    local gTIME="${gBak_Time:12:2}:${gBak_Time:15:2}:${gBak_Time:18:2}"
    local gBackupLOG=$(echo "${gBak_Dir}/BackupLOG.txt")

    #
    # Print Header.
    #
    echo "  Backup Recovery HD(BaseSystem.dmg)"                                                   > "${gBackupLOG}"
    echo ''                                                                                       >>"${gBackupLOG}"
    echo "  DATE:                     $gDAY"                                                      >>"${gBackupLOG}"
    echo "  TIME:                     $gTIME"                                                     >>"${gBackupLOG}"
    local gRecentFileMD5=$(md5 -q "${gBak_BaseSystem}")
    echo "  Origin Recovery HD MD5:   ${gRecentFileMD5}"                                          >>"${gBackupLOG}"
    local gPatchedFileMD5=$(md5 -q "${gBaseSystem_PATCH}")
    echo "  Patched Recovery HD MD5:  ${gPatchedFileMD5}"                                         >>"${gBackupLOG}"
    echo ''                                                                                       >>"${gBackupLOG}"
}

#
#--------------------------------------------------------------------------------
#

function _bakRecHDIsRequire()
{
    gLastOpenedFileMD5=$(md5 -q "${gRecoveryHD_DMG}")

    if [ -d "${REPO}/Backups" ];
      then
        if [[ `ls ${REPO}/Backups/*` == *'.txt'* ]];
          then
            gBakFileNames=($(ls ${REPO}/Backups/*/*.txt))
        fi
    fi

    if [[ "${#gBakFileNames[@]}" -gt 0 ]];
      then
        gBakFileMD5=($(cat ${gBakFileNames[@]} | grep 'Patched Recovery HD MD5:' | sed -e 's/.*: //' -e 's/ //'))
        for checksum in "${gBakFileMD5[@]}"
        do
          if [[ $checksum == $gLastOpenedFileMD5 && ${gStop_Bak} != ${kBASHReturnSuccess} ]];
            then
              _PRINT_MSG "OK: Backup found. No more patch operations need"
              gStop_Bak=${kBASHReturnSuccess}
          fi
        done
    fi
}

#
#--------------------------------------------------------------------------------
#

function _installExTool()
{
    local gExecutableFiles=("iasl" "mnt" "rebuild" "umnt")
    local gBinRepo="/usr/sbin"
    for file in "${gExecutableFiles}"
    do
      _tidy_exec "sudo cp -RX ${REPO}/tools/${file} ${gBinRepo}" "Install ${file} to ${gBinRepo}"
    done
}

#
#--------------------------------------------------------------------------------
#

function _recoveryhd_fix()
{
    #
    # Fixed RecoveryHD issues (c) syscl.
    #
    # Check BooterConfig = 0x2A.
    #
    local target_BooterConfig="0x2A"
    local gClover_BooterConfig=$(awk '/<key>BooterConfig<\/key>.*/,/<\/string>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g')
    #
    # Added BooterConfig = 0x2A(0x00101010).
    #
    if [ -z $gClover_BooterConfig ];
      then
        ${doCommands[1]} "Add ':RtVariables:BooterConfig' string" ${config_plist}
        ${doCommands[1]} "Set ':RtVariables:BooterConfig' $target_BooterConfig" ${config_plist}
      else
        #
        # Check if BooterConfig = 0x2A.
        #
        if [[ $gClover_BooterConfig != $target_BooterConfig ]];
          then
            #
            # Yes, we have to touch/modify the config.plist.
            #
            ${doCommands[1]} "Set ':RtVariables:BooterConfig' $target_BooterConfig" ${config_plist}
        fi
    fi

    #
    # Mount Recovery HD.
    #
    local gMountPoint="/tmp/RecoveryHD"
    local gBaseSystem_RW="/tmp/BaseSystem_RW.dmg"
    local gBaseSystem_PATCH="/tmp/BaseSystem_PATCHED.dmg"

    #
    # Locate Recovery HD
    #
    _tidy_exec "diskutil mount ${gRecoveryHD}" "Mount ${gRecoveryHD}"

    #
    # Check if backup RecoveryHD is required
    #
    _bakRecHDIsRequire
    if [[ ${gStop_Bak} == ${kBASHReturnSuccess} ]]; then
        #
        # Already patched Recovery HD, return
        #
        return;
    fi

    #
    # let's get started to backup and patch RecoveryHD
    #
    _touch "${gMountPoint}"

    #
    # Gain origin file format(e.g. UDZO...).
    #
    local gBaseSystem_FS=$(hdiutil imageinfo "${gRecoveryHD_DMG}" | grep -i "Format:" | sed -e 's/.*://' -e 's/ //')
    local gTarget_FS=$(echo 'UDRW')

    #
    # Backup origin BaseSystem.dmg to ${REPO}/Backups
    #
    _touch "${gBak_Dir}"
    cp "${gRecoveryHD_DMG}" "${gBak_Dir}"
    gBak_BaseSystem="${gBak_Dir}/BaseSystem.dmg"
    chflags nohidden "${gBak_BaseSystem}"

    #
    # Start to override.
    #
    _PRINT_MSG "--->: Convert ${gBaseSystem_FS}(r/o) to ${gTarget_FS}(r/w) ..."
    _tidy_exec "hdiutil convert "${gBak_BaseSystem}" -format ${gTarget_FS} -o ${gBaseSystem_RW} -quiet" "Convert ${gBaseSystem_FS}(r/o) to ${gTarget_FS}(r/w)"
    _tidy_exec "hdiutil attach "${gBaseSystem_RW}" -nobrowse -quiet -readwrite -noverify -mountpoint ${gMountPoint}" "Attach Recovery HD"
    _unlock_pixel_clock
    _tidy_exec "hdiutil detach $gMountPoint" "Detach mountpoint"
    #
    # Convert to origin format.
    #
    _PRINT_MSG "--->: Convert ${gTarget_FS}(r/w) to ${gBaseSystem_FS}(r/o) ..."
    _tidy_exec "hdiutil convert "${gBaseSystem_RW}" -format ${gBaseSystem_FS} -o ${gBaseSystem_PATCH} -quiet" "Convert ${gTarget_FS}(r/w) to ${gBaseSystem_FS}(r/o)"
    _PRINT_MSG "--->: Updating Recovery HD for DELL XPS 13 9350..."
    cp ${gBaseSystem_PATCH} "${gRecoveryHD_DMG}"
    chflags hidden "${gRecoveryHD_DMG}"
    #
    # Backup and patch finish, print out RecoveryHD dmg info
    #
    _printBackupLOG

    #
    # Clean redundant dmg files.
    #
    _tidy_exec "rm $gBaseSystem_RW $gBaseSystem_PATCH" "Clean redundant dmg files"
    _tidy_exec "diskutil unmount ${gRecoveryHD}" "Unmount ${gRecoveryHD}"
}

#
#--------------------------------------------------------------------------------
#

function _serialMLBGen()
{
    local gGetModelFromConfig=`${doCommands[1]} "Print :SMBIOS:ProductName" ${config_plist}`
    local gGenerateSerial=`"${REPO}"/tools/macgen/mg-serial ${gGetModelFromConfig}`
    local gGenerateMLB=`"${REPO}"/tools/macgen/mg-mlb-serial ${gGetModelFromConfig} ${gGenerateSerial}`
    local gGenerateUUID=$(uuidgen)

    if [[ $gScriptFirstRun == "true" ]]; then
       ${doCommands[1]} "Add ':RtVariables:MLB' string" ${config_plist}
       ${doCommands[1]} "Set ':RtVariables:MLB' ${gGenerateMLB}" ${config_plist}
       ${doCommands[1]} "Add ':RtVariables:ROM' string" ${config_plist}
       ${doCommands[1]} "Set ':RtVariables:ROM' UseMacAddr0" ${config_plist}
       ${doCommands[1]} "Set ':SMBIOS:SerialNumber' ${gGenerateSerial}" ${config_plist}
       ${doCommands[1]} "Add ':SMBIOS:SmUUID' string" ${config_plist}
       ${doCommands[1]} "Set ':SMBIOS:SmUUID' ${gGenerateUUID}" ${config_plist}
    fi


    if [[ $gRegenerateSerial == "true" ]]; then
        ${doCommands[1]} "Set ':RtVariables:MLB' ${gGenerateMLB}" ${config_plist}
        ${doCommands[1]} "Set ':RtVariables:ROM' UseMacAddr0" ${config_plist}
        ${doCommands[1]} "Set ':SMBIOS:SerialNumber' ${gGenerateSerial}" ${config_plist}
        ${doCommands[1]} "Set ':SMBIOS:SmUUID' ${gGenerateUUID}" ${config_plist}
    fi
}

function main()
{
    #
    # Get argument.
    #
    gArgv=$(echo "$@" | tr '[:lower:]' '[:upper:]')
    if [[ "$gArgv" == *"-D"* || "$gArgv" == *"-DEBUG"* ]];
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
    #
    # rlse: no update, no install audio, no rebuild
    #
    if [[ "$gArgv" == *"-RLSE"* ]];
      then
        gDisableRebuildnAudioInst=${kBASHReturnSuccess}
      else
        gDisableRebuildnAudioInst=${kBASHReturnFailure}
    fi
    #
    # Sync all files from https://github.com/syscl/XPS9350-macOS
    #
    # Check if github is available
    #
    if [[ ${gDisableRebuildnAudioInst} == ${kBASHReturnFailure} ]];
      then
        _update
    fi

    #
    # set model type(Iris vs non-Irsi)
    #
    _setModelType

    #
    # prestage cleanup
    #
    _tidy_exec "${REPO}/tools/cleanup" "Pre stage cleanup"

    #
    # Generate dir.
    #
    _tidy_exec "_touch "${REPO}/DSDT"" "Create ./DSDT"
    _tidy_exec "_touch "${prepare}"" "Create ./DSDT/prepare"
    _tidy_exec "_touch "${precompile}"" "Create ./DSDT/precompile"
    _tidy_exec "_touch "${compile}"" "Create ./DSDT/compile"


    #
    # Get user information
    #
    # get ESP
    #
    diskutil list
    printf "Enter ${RED}EFI's${OFF} IDENTIFIER, e.g. ${BOLD}disk0s1${OFF}"
    read -p ": " targetEFI
    #
    # Choose touchpad kext you prefer
    #
    printf "Current System Version: MacOS ${current_OSVer}\n"
    printf "Available touchpad kext:\n"
    printf "[   ${BLUE}1${OFF}  ] ApplePS2SmartTouchPad (10.11)\n"
#printf "[   ${BLUE}2${OFF}  ] VoodooPS2Controller\n (10.12+)"
    printf "[   ${BLUE}2${OFF}  ] VoodooI2C\n (10.12+)"
    printf "Please choose the desired touchpad kext (1 or 2)"
    read -p ": " gSelect_TouchPad_Drv
    case "${gSelect_TouchPad_Drv}" in
      1     ) _PRINT_MSG "NOTE: Use ${BLUE}ApplePS2SmartTouchPad${OFF}"
              ;;

      2     ) _PRINT_MSG "NOTE: Use ${BLUE}VoodooPS2Controller${OFF}"
              ;;

      *     ) _PRINT_MSG "NOTE: Invalid number, use default setting"
              local gApplePS2SmartTouchPadIsPresent=$(kextstat |grep -i "ApplePS2SmartTouchPad")
              if [[ ${gApplePS2SmartTouchPadIsPresent} != "" ]];
                then
                  #
                  # Use ApplePS2SmartTouchPad
                  #
                  gSelect_TouchPad_Drv=1
                else
                  #
                  # Use VoodooPS2Controller
                  #
                  gSelect_TouchPad_Drv=2
              fi
              ;;
    esac


    #
    # Mount esp
    #
    _tidy_exec "diskutil mount ${targetEFI}" "Mount ${targetEFI}"
    _getESPMntPoint ${targetEFI}
    _setESPVariable

    #
    # Ensure / Force Graphics card to power.
    #
    _initIntel
    _getEDID

    #
    # Copy origin aml to raw.
    #
    if [ -f "${gESPMountPoint}/EFI/CLOVER/ACPI/origin/DSDT.aml" ];
      then
        local gOrgAcpiRepo="${gESPMountPoint}/EFI/CLOVER/ACPI/origin"

        _tidy_exec "cp ${gOrgAcpiRepo}/DSDT.aml ${gOrgAcpiRepo}/FACP.aml ${gOrgAcpiRepo}/SSDT-*.aml "${decompile}"" "Copy untouch ACPI tables"
      else
        _PRINT_MSG "NOTE: Warning!! DSDT and SSDTs doesn't exist! Press Fn+F4 under Clover to dump ACPI tables"
        # ERROR.
        #
        # Note: The exit value can be anything between 0 and 255 and thus -1 is actually 255
        #       but we use -1 here to make it clear (obviously) that something went wrong.
        #
        exit -1
    fi

    #
    # Choose whether or not to regenerate serial
    #
    gRegenerateSerial="false"
    gScriptFirstRun="true"

    if [ `${doCommands[1]} "Print :SMBIOS:SerialNumber" ${config_plist}` != 'FAKESERIAL' ]; then
        printf "Generate new Serial, MLB, UUID? [Y/N]"
        read -p ": " local gRegenerateSerialChoice
        if [ "$gRegenerateSerialChoice" == 'Y' ] || [ "$gRegenerateSerialChoice" == 'y' ]; then
            gRegenerateSerial="true"
            gScriptFirstRun="false"
        else
            gRegenerateSerial="false"
            gScriptFirstRun="false"
        fi
    fi

    #
    # Rename SSDT-x-* to SSDT-x to prevent compile error caused by newer version of Clover
    # credits @squash- @zombiethebest
    #
    _PRINT_MSG "--->: ${BLUE}Renaming SSDTs...${OFF}"
    if [ -e "${REPO}"/DSDT/raw/SSDT-0.dsl ]; then
      # Extracted Files are Good - nothing to do
      _PRINT_MSG "OK: No need to rename."
    else
      # We have to rename the Files
      mv "${REPO}"/DSDT/raw/SSDT-1-sensrhub.aml "${REPO}"/DSDT/raw/SSDT-1.aml
      for i in {0..6}
      do
        mv "${REPO}"/DSDT/raw/SSDT-${i}* "${REPO}"/DSDT/raw/SSDT-${i}.aml
      done
      for i in {7..13}
      do
        mv "${REPO}"/DSDT/raw/SSDT-${i}x* "${REPO}"/DSDT/raw/SSDT-${i}x.aml
      done
      mv "${REPO}"/DSDT/raw/SSDT-14* "${REPO}"/DSDT/raw/SSDT-14.aml
      _PRINT_MSG "OK: SSDTs successfully renamed."
    fi

    #
    # Decompile acpi tables
    #
    cd "${REPO}"
    _PRINT_MSG "--->: ${BLUE}Disassembling tables...${OFF}"
    _tidy_exec ""${REPO}"/tools/iasl -da -dl -fe "${REPO}"/DSDT/patches/refs.txt "${REPO}"/DSDT/raw/DSDT.aml "${REPO}"/DSDT/raw/SSDT-*.aml" "Disassemble DSDT"
    _tidy_exec ""${REPO}"/tools/iasl "${REPO}"/DSDT/raw/FACP.aml" "Disassemble FACP"

    #
    # Search specification tables by syscl/Yating Zhou.
    #
    _tidy_exec "_find_acpi" "Search specification tables by syscl/Yating Zhou"

    #
    # DSDT Patches.
    #
    # Rename definition block first
    #
    sed -ig 's/DefinitionBlock ("", "DSDT", 2, "DELL  ", "CBX3   ", 0x01072009)/DefinitionBlock ("", "DSDT", 3, "APPLE ", "MacBook", 0x00080001)/' "${REPO}"/DSDT/raw/DSDT.dsl
    _PRINT_MSG "--->: ${BLUE}Patching DSDT.dsl${OFF}"
    _tidy_exec "patch_acpi DSDT syntax "rename_DSM"" "_DSM->XDSM"
    _tidy_exec "patch_acpi DSDT syscl "syscl_fixFieldLen"" "Fix word field length Dword->Qword credit syscl"
    _tidy_exec "patch_acpi DSDT syscl "system_OSYS"" "OS Check Fix"
    if [[ ${gSelect_TouchPad_Drv} == 1 ]];
      then
        #
        # Fix ApplePS2SmartTouchPad
        #
        _tidy_exec "patch_acpi DSDT syscl "syscl_fixBrightnesskey"" "Fix brightness keys(F11/F12)"
      else
        #
        # Fix VoodooPS2Controller
        #
        _tidy_exec "patch_acpi DSDT syscl "syscl_fixBrightnesskey_VoodooPS2"" "Fix brightness keys(F11/F12)"
    fi
#
# I2C patches
#
    _tidy_exec "patch_acpi DSDT syscl "syscl_win10patches"" "Windows 10 DSDT Patch for VoodooI2C"
    _tidy_exec "patch_acpi DSDT syscl "syscl_i2c"" "Skylake controller patches for VoodooI2C"
    _tidy_exec "patch_acpi DSDT syscl "syscl_i2ce"" "GPI0 Status patch"
    _tidy_exec "patch_acpi DSDT syscl "syscl_gpio_elan1200"" "GPIO Pinning for ELAN1200 by HackinDoge"
#
# 
#
    _tidy_exec "patch_acpi DSDT syscl "syscl_HDAS2HDEF"" "HDAS->HDEF"
    _tidy_exec "patch_acpi DSDT syscl "audio_HDEF-layout1"" "Inject Audio Info"
    _tidy_exec "patch_acpi DSDT graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"
    _tidy_exec "patch_acpi DSDT syscl "syscl_USBX_n_PNLF"" "Inject USBX and PNLF credit syscl"
    _tidy_exec "patch_acpi DSDT usb "usb_prw_0x6d_xhc_skl"" "Fix USB _PRW"
    _tidy_exec "patch_acpi DSDT system "system_IRQ"" "IRQ Fix"
    _tidy_exec "patch_acpi DSDT system "system_SMBUS"" "SMBus Fix"
    _tidy_exec "patch_acpi DSDT system "system_ADP1"" "AC Adapter Fix"
    _tidy_exec "patch_acpi DSDT system "system_MCHC"" "Add MCHC"
    _tidy_exec "patch_acpi DSDT system "system_WAK2"" "Fix _WAK Arg0 v2"
    _tidy_exec "patch_acpi DSDT system "system_IMEI"" "Add IMEI"
    _tidy_exec "patch_acpi DSDT system "system_Mutex"" "Fix Non-zero Mutex"
    _tidy_exec "patch_acpi DSDT syscl "syscl_fixRefs"" "Fix MDBG Error credit x4080, syscl"
#   _tidy_exec "patch_acpi DSDT syscl "syscl_ALSD2ALS0"" "ALSD->ALS0"
    #
    # Modificate ACPI for macOS to load devices correctly
    #
    _tidy_exec "patch_acpi DSDT syscl "syscl_PPMCnPMCR"" "PPMC and PMCR combine together credit syscl"
    _tidy_exec "patch_acpi DSDT syscl "syscl_DMAC"" "Insert DMAC(PNP0200)"
    _tidy_exec "patch_acpi DSDT syscl "syscl_MATH"" "Make Device(MATH) load correctly in macOS"
    _tidy_exec "patch_acpi DSDT syscl "syscl_SLPB"" "SBTN->SLPB with correct _STA 0x0B"
    _tidy_exec "patch_acpi DSDT syscl "syscl_iGPU_MEM2"" "iGPU TPMX to MEM2"
    _tidy_exec "patch_acpi DSDT syscl "syscl_IMTR2TIMR"" "IMTR->TIMR, _T_x->T_x"
    _tidy_exec "patch_acpi DSDT syscl "syscl_PXSX2ARPT"" "PXSX2ARPT with _PWR fix"
    _tidy_exec "patch_acpi DSDT syscl "syscl_USB"" "Correct USB(XHC) information and injection credit syscl"
#    _tidy_exec "patch_acpi DSDT syscl "syscl_rmB0D4"" "Remove Device(B0D4)"
    _tidy_exec "patch_acpi DSDT syscl "rmWMI"" "Remove WMI(PNP0C14)"
    # RP09.PXSX -> RP09.SSD0
    _tidy_exec "patch_acpi DSDT syscl "syscl_SSD"" "Inject SSD device property credit syscl"
    #sed -ig 's/\.RP09\.PXSX/\.RP09\.SSD0/' "${REPO}"/DSDT/raw/DSDT.dsl
    local gNVMeKextIsLoad=$(kextstat |grep -i "NVME")
    if [[ ${gNVMeKextIsLoad} != "" ]]; then
        #
        # NVMe drivers are loaded, inject properties for better power management
        #
        _tidy_exec "patch_acpi DSDT syscl "syscl_GTF0"" "Declare GTF0 method object credit syscl"
        _tidy_exec "patch_acpi DSDT syscl "syscl_NVMe"" "Inject NVMe power management properties credit Pike R. Alpha, syscl"
    fi
    # PBTN -> PWRB
    #sed -ig 's/PBTN/PWRB/' "${REPO}"/DSDT/raw/DSDT.dsl
    _tidy_exec "patch_acpi DSDT syscl "syscl_PWRB"" "Remove _PWR, _PSW in PWRB(PNP0C0C)"
    # Inject reg-ltrovr for IOPCIFamily::setLatencyTolerance setting ltrOffset for PCI devices successfully (c) syscl
    _tidy_exec "patch_acpi DSDT syscl "syscl_ltrovr"" "Inject reg-ltrovr for IOPCIFamily::setLatencyTolerance setting ltrOffset for PCI devices successfully (c) syscl"
    # Fix shutdown
    _tidy_exec "patch_acpi DSDT system "system_Shutdown2"" "Fix shutdown become reboot issue"
    # Added deep sleep & deep idle as per Pike R. Alpha
#_tidy_exec "patch_acpi DSDT syscl "system_deep_idle"" "Added deep sleep and deep idle properties"
    # ECDV -> EC
#sed -ig 's/ECDV/EC/' /DSDT/raw/DSDT.dsl
    _tidy_exec "rm "${REPO}"/DSDT/raw/DSDT.dslg" "Remove DSDT backup"

    #
    # DptfTa Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${DptfTa}.dsl${OFF}"
    _tidy_exec "patch_acpi_force ${DptfTa} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"

    #
    # SaSsdt Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${SaSsdt}.dsl${OFF}"
    _tidy_exec "patch_acpi_force ${SaSsdt} syntax "rename_DSM"" "_DSM->XDSM"
    _tidy_exec "patch_acpi_force ${SaSsdt} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"

    #
    # sensrhub patches
    #
    _PRINT_MSG "--->: ${BLUE}Fixing ${sensrhub}.dsl${OFF}"
    _tidy_exec "patch_acpi_force ${sensrhub} syntax "rename_DSM"" "_DSM->XDSM"
    _tidy_exec "patch_acpi_force ${sensrhub} syscl "syscl_fix_PARSEOP_IF"" "Fix PARSEOP_IF error credit syscl"

    #
    # fix reboot issue credit syscl
    #
    _PRINT_MSG "--->: ${BLUE}Fixing reboot issue${OFF}"
    _tidy_exec "_fixReboot" "Fix reboot issue credit syscl"

    #
    # Copy all tables to precompile.
    #
    _PRINT_MSG "--->: ${BLUE}Copying tables to precompile...${OFF}"
    _tidy_exec "cp "${raw}/"*.dsl "${precompile}"" "Copy tables to precompile"

    #
    # Copy raw tables to compile.
    #
    _PRINT_MSG "--->: ${BLUE}Copying untouched tables to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${raw}"/SSDT-*.aml "$compile"" "Copy untouched tables to ./DSDT/compile"

    #
    # Compile tables.
    #
    _PRINT_MSG "--->: ${BLUE}Compiling tables...${OFF}"
    _tidy_exec "compile_table "DSDT"" "Compiling DSDT"
    _tidy_exec "compile_table "${DptfTa}"" "Compile DptfTa"
    _tidy_exec "compile_table "${SaSsdt}"" "Compile SaSsdt"
    _tidy_exec "compile_table "${sensrhub}"" "Compile sensrhub"

    #
    # Copy SSDT-PNLF.aml.
    #
    _PRINT_MSG "--->: ${BLUE}Copying SSDT-PNLF.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-PNLF.aml "${compile}"" "Copy SSDT-PNLF.aml to ./DSDT/compile"

    #
    # Copy SSDT-ALC256.aml.
    #
    _PRINT_MSG "--->: ${BLUE}Copying SSDT-ALC256.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-ALC256.aml "${compile}"" "Copy SSDT-ALC256.aml to ./DSDT/compile"

    #
    # Copy SSDT-rmne.aml.
    #
    _PRINT_MSG "--->: ${BLUE}Copying SSDT-rmne.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-rmne.aml "${compile}"" "Copy SSDT-rmne.aml to ./DSDT/compile"

    #
    # Decide which mode: hwp?
    #
    _hwpArgvChk
    if [[ ${gCp_SSDT_pr} != ${kBASHReturnSuccess} ]];
      then
        #
        # Detect which SSDT for processor to be installed.
        #
        gCpuName=$(sysctl machdep.cpu.brand_string |sed -e "/.*) /s///" -e "/ CPU.*/s///")
        _tidy_exec "cp "${prepare}"/CpuPm-${gCpuName}.aml "${compile}"/SSDT-pr.aml" "Generate C-States and P-State for Intel ${BLUE}${gCpuName}${OFF}"
#      else
        #
        # Full HWP power management credit syscl, dpassmor, Pike R. Alpha
        #
#        _tidy_exec "cp "${prepare}"/SSDT-pr.aml "${compile}"/SSDT-pr.aml" "Install SSDT-pr for writing plugin-type to registry"
        #
        # X86PlatformPluginInjector method credit syscl
        #
#_tidy_exec "sudo cp -RX "${REPO}/Kexts/X86PlatformPluginInjector/X86PlatformPluginInjector.kext" "${gExtensions_Repo[0]}"" "Install X86PlatformPluginInjector (c) syscl"
    fi

    #
    # Install SsdtS3
    #
    _PRINT_MSG "--->: ${BLUE}Installing SSDT-XPS13SKL.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-XPS13SKL.aml "${compile}"" "Install SsdtS3 table"

    #
    # Install ARPT
    #
    _PRINT_MSG "--->: ${BLUE}Installing SSDT-ARPT-RP05.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-ARPT-RP05.aml "${compile}"" "Install ARPT table"

    #
    # Install SSDT-XHC
    #
    _PRINT_MSG "--->: ${BLUE}Installing SSDT-XHC.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-XHC.aml "${compile}"" "Install Xhci table"

    #
    # Rename a High Sierra Kext to prevent BT Issue
    #
    if [ "${isSierra}" -eq 0 ];
      then
        if [ -f "${gExtensions_Repo[0]}/AirPortBrcmNIC-MFG.kext" ]; then
          _tidy_exec "sudo mv "${gExtensions_Repo[0]}/AirPortBrcmNIC-MFG.kext" "${gExtensions_Repo[0]}/AirPortBrcmNIC-MFG.bak"" "Rename AirPortBrcmNIC-MFG.kext..."
        fi
    fi
    #
    # Clean up dynamic tables USB related tables
    #
    _tidy_exec "rm "${compile}"SSDT-*x.aml" "Clean dynamic SSDTs"
    for rmssdt in "${gRm_SSDT_Tabl[@]}"
    do
      _tidy_exec "rm "${compile}"$rmssdt.aml" "Drop ${rmssdt}"
    done

    #
    # Copy AML to destination place.
    #
    _tidy_exec "_touch "${gESPMountPoint}/EFI/CLOVER/ACPI/patched"" "Create ${gESPMountPoint}/EFI/CLOVER/ACPI/patched"
    _tidy_exec "cp "${compile}"*.aml ${gESPMountPoint}/EFI/CLOVER/ACPI/patched" "Copy tables to ${gESPMountPoint}/EFI/CLOVER/ACPI/patched"
    for rmssdt in "${gRm_SSDT_Tabl[@]}"
    do
      if [ -f ${gESPMountPoint}/EFI/CLOVER/ACPI/patched/$rmssdt.aml ]; then
          _tidy_exec "rm ${gESPMountPoint}/EFI/CLOVER/ACPI/patched/$rmssdt.aml" "Drop ${gESPMountPoint}/EFI/CLOVER/ACPI/patched/${rmssdt}"
      fi
    done

    #
    # Refresh kext in Clover.
    #
    _update_clover

    #
    # Generate and set Mac Serial, MLB, and UUID
    #
    if [[ $gRegenerateSerial == "true" ]] && [[ $gScriptFirstRun == "false" ]]; then
        _PRINT_MSG "--->: ${BLUE}Regenerating and setting Mac Serial, MLB and UUID${OFF}"
        _serialMLBGen
    elif [[ $gScriptFirstRun == "true" ]] && [[ $gRegenerateSerial == "false" ]]; then
        _PRINT_MSG "--->: ${BLUE}Generating and setting Mac Serial, MLB and UUID${OFF}"
        _serialMLBGen
    fi

    #
    # Refresh BootCamp theme.
    #
    _update_thm

    #
    # Install audio.
    #
    if [[ ${gDisableRebuildnAudioInst} == ${kBASHReturnFailure} ]]; then
        _PRINT_MSG "--->: ${BLUE}Installing audio...${OFF}"
        _tidy_exec "install_audio" "Install audio"
    fi

    #
    # Fix HiDPI boot graphics issue
    #
    if [[ $gHorizontalRez -gt 1920 || $gSystemHorizontalRez -gt 1920 ]];
    _PRINT_MSG "--->: ${BLUE}Setting EFILoginHiDPI & UIScale...${OFF}"
    then
      ${doCommands[1]} "Set :BootGraphics:EFILoginHiDPI 1" "${config_plist}"
      ${doCommands[1]} "Set :BootGraphics:UIScale 2" "${config_plist}"
    else
      ${doCommands[1]} "Set :BootGraphics:EFILoginHiDPI 0" "${config_plist}"
      ${doCommands[1]} "Set :BootGraphics:UIScale 1" "${config_plist}"
    fi

    #
    # Patch IOKit/CoreDisplay.
    #
    if [ $gPatchIOKit -eq 0 ];
      then
        #
        # Patch IOKit.
        #
        _PRINT_MSG "--->: ${BLUE}Unlocking maximum pixel clock...${OFF}"
        if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
          then
            if [ "${isSierra}" -eq 0 ];
              then
                #
                # 10.13 - Using Lilu.kext + CoreDisplayFixUp.kext to prevent clipboard crash + BT PATCH
                #
                local KEXT_DIR="${gESPMountPoint}/EFI/CLOVER/kexts/${gOSVer}"
                _tidy_exec "sudo cp -RX "${REPO}/Kexts/coredisplay_fixup/CoreDisplayFixUp.kext" "${KEXT_DIR}/CoreDisplayFixUp.kext"" "Patch and sign framework"
              else
                #
                # 10.12
                #
                gTarget_Framework_Repo="/System/Library/Frameworks/CoreDisplay.framework/Versions/Current/CoreDisplay"
                sudo perl -i.bak -pe 's|\xB8\x01\x00\x00\x00\xF6\xC1\x01\x0F\x85|\x33\xC0\x90\x90\x90\x90\x90\x90\x90\xE9|sg' ${gTarget_Framework_Repo}
                _tidy_exec "sudo codesign -f -s - ${gTarget_Framework_Repo}" "Patch and sign framework"
                _tidy_exec "rebuild_dyld_shared_cache" "Rebuld dyld_shared_cache"
            fi
          else
            #
            # 10.12-
            #
            gTarget_Framework_Repo="/System/Library/Frameworks/IOKit.framework/Versions/Current/IOKit"
            sudo perl -i.bak -pe 's|\xB8\x01\x00\x00\x00\xF6\xC1\x01\x0F\x85|\x33\xC0\x90\x90\x90\x90\x90\x90\x90\xE9|sg' ${gTarget_Framework_Repo}
            _tidy_exec "sudo codesign -f -s - ${gTarget_Framework_Repo}" "Patch and sign framework"
            _tidy_exec "rebuild_dyld_shared_cache" "Rebuld dyld_shared_cache"
        fi
    fi

    _setPlatformId

    if [ ${gModelType} == 1 ]; then
        #
        # Lead to lid wake on 0x19260004 by syscl/lighting/Yating Zhou.
        #
        _PRINT_MSG "--->: ${BLUE}Leading to lid wake on 0x19260004 (c) syscl/lighting/Yating Zhou...${OFF}"
        _tidy_exec "_check_and_fix_config" "Lead to lid wake on 0x19260004"
    fi

    #
    # Fix issue that external devices ejected improperly upon sleep (c) syscl/lighting/Yating Zhou.
    #
    _fix_usb_ejected_improperly

    #
    # Fix hibernatemode
    #
    _twhibernatemod

    #
    # Disable autopoweroff
    #
    _tw_autopoweroff

    #
    # Disable standby
    #
    _tw_standby

    #
    # Fixed Recovery HD entering issues (c) syscl.
    #
    gRecoveryHD=$(_locate_rhd ${targetEFI})
    if [ ! -z ${gRecoveryHD} ];
      then
        #
        # Recovery HD found, patch it or not?
        #
        if [ $gPatchRecoveryHD -eq 0 ];
          then
            #
            # Yes, patch Recovery HD.
            #
            _recoveryhd_fix
        fi
    fi

    #
    # Rebuild kernel extensions cache.
    #
    if [[ ${gDisableRebuildnAudioInst} == ${kBASHReturnFailure} ]]; then
        _PRINT_MSG "--->: ${BLUE}Rebuilding kernel extensions cache...${OFF}"
        _tidy_exec "rebuild_kernel_cache" "Rebuild kernel extensions cache"
    fi

    #
    # Clean up backup
    #
    _del "${gESPMountPoint}/EFI/CLOVER/config.plistg"

    _PRINT_MSG "NOTE: Congratulations! All operation has been completed"
    _PRINT_MSG "NOTE: Reboot now. -${BOLD}syscl/lighting/Yating Zhou @PCBeta${OFF}"
}

#==================================== START =====================================

main "$@"

#================================================================================

exit ${RETURN_VAL}
