#!/bin/sh

#
# syscl/Yating Zhou/lighting from bbs.PCBeta.com
# Merge for Dell Precision M3800 and XPS15 (9530).
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
# Path and filename setup.
#
decompile="${REPO}/DSDT/raw/"
precompile="${REPO}/DSDT/precompile/"
compile="${REPO}/DSDT/compile/"
tools="${REPO}/tools/"
raw="${REPO}/DSDT/raw"
prepare="${REPO}/DSDT/prepare"
config_plist="/Volumes/EFI/EFI/CLOVER/config.plist"
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
t_drivers64UEFI="/Volumes/EFI/EFI/CLOVER/drivers64UEFI"
clover_tools="${REPO}/CLOVER/tools"
t_clover_tools="/Volumes/EFI/EFI/CLOVER/tools"

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
cAzulFrameBuffer=""
fAzulFrameBuffer=""
rAzulFrameBuffer=""
nAzulFrameBuffer=""
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
gInjector_Repo="/tmp/AppleHDA_ALC668.kext"
gAppleHDA_Config="${gInjector_Repo}/Contents/Info.plist"
doCommands=("${REPO}/tools/iasl" "/usr/libexec/plistbuddy -c" "perl -p -e 's/(\d*\.\d*)/9\1/'")

#
# Set delimitation OS ver
#
let gDelimitation_OSVer=12

#
# Define target website
#
target_website=https://github.com/syscl/M3800

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
    # Sync all files from https://github.com/syscl/M3800
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
    diskutil list | grep -i "${gDisk_INF:0:5}" | grep "Recovery HD" |sed 's/.*MB   //'
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
    "${REPO}"/tools/iasl -vr -w1 -ve -p "${compile}"$1.aml "${precompile}"$1.dsl
}

#
#--------------------------------------------------------------------------------
#

function rebuild_kernel_cache()
{
    #
    # Repair the permission & refresh kernelcache.
    #
    if [ $gTriggerLE -eq 0 ];
      then
        #
        # Yes, we do touch /L*/E*.
        #
        sudo touch /Library/Extensions
    fi

    #
    # /S*/L*/E* must be touched to prevent some potential issues.
    #
    sudo touch /System/Library/Extensions
    sudo /bin/kill -1 `ps -ax | awk '{print $1" "$5}' | grep kextd | awk '{print $1}'`
    sudo kextcache -u /
}

#
#--------------------------------------------------------------------------------
#

function install_audio()
{
    #
    # Remove previous AppleHDA_ALC668.kext & CodecCommander.kext.
    #
    for extensions in ${gExtensions_Repo[@]}
    do
      _del $extensions/AppleHDA_ALC668.kext
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

    replace=`${doCommands[1]} "Print :NSHumanReadableCopyright" ${gAppleHDA_Config} | ${doCommands[2]}`
    ${doCommands[1]} "Set :NSHumanReadableCopyright '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleGetInfoString" ${gAppleHDA_Config} | ${doCommands[2]}`
    ${doCommands[1]} "Set :CFBundleGetInfoString '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleVersion" ${gAppleHDA_Config} | ${doCommands[2]}`
    ${doCommands[1]} "Set :CFBundleVersion '$replace'" ${gAppleHDA_Config}
    replace=`${doCommands[1]} "Print :CFBundleShortVersionString" ${gAppleHDA_Config} | ${doCommands[2]}`
    ${doCommands[1]} "Set :CFBundleShortVersionString '$replace'" ${gAppleHDA_Config}
    ${doCommands[1]} "Add ':HardwareConfigDriver_Temp' dict" ${gAppleHDA_Config}
    ${doCommands[1]} "Merge ${gExtensions_Repo[0]}/AppleHDA.kext/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" ${gAppleHDA_Config}
    ${doCommands[1]} "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':HardwareConfigDriver_Temp'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" ${gAppleHDA_Config}
    ${doCommands[1]} "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" ${gAppleHDA_Config}
    ${doCommands[1]} "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" ${gAppleHDA_Config}
    ${doCommands[1]} "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" ${gAppleHDA_Config}
    ${doCommands[1]} "Merge ${REPO}/Kexts/audio/Resources/ahhcd.plist ':IOKitPersonalities:HDA Hardware Config Resource'" ${gAppleHDA_Config}
    _tidy_exec "sudo cp -RX "${gInjector_Repo}" "${gExtensions_Repo[1]}"" "Install AppleHDA_ALC668"


    #
    # Gain all binary patches from config.
    #
    gClover_kexts_to_patch_data=$(awk '/<key>KextsToPatch<\/key>.*/,/<\/array>/' ${config_plist})

    #
    # Added Clover patch for ALC668 in Sierra
    #
    # Stage 1 of 4
    #
    cALC668_Stage1="Enable Realtek ALC668 stage 1 of 4"
    fALC668_Stage1="8408ec10"
    rALC668_Stage1="00000000"
    nALC668_Stage1="AppleHDA"
    #
    # Stage 2 of 4
    #
    cALC668_Stage2="Enable Realtek ALC668 stage 2 of 4"
    fALC668_Stage2="8508ec10"
    rALC668_Stage2="00000000"
    nALC668_Stage2="AppleHDA"
    #
    # Stage 3 of 4
    #
    cALC668_Stage3="Enable Realtek ALC668 stage 3 of 4"
    fALC668_Stage3="8B19D411"
    rALC668_Stage3="6806ec10"
    nALC668_Stage3="AppleHDA"
    #
    # Stage 4 of 4
    #
    cALC668_Stage5="Enable Realtek ALC668 stage 4 of 4"
    fALC668_Stage5="8A19D411"
    rALC668_Stage5="00000000"
    nALC668_Stage5="AppleHDA"
    #
    # Chrome audio issues patch stage 1 of 2
    #
    cALC668_Stage6="Sleep loose sound issue patch 1 of 2"
    fALC668_Stage6="41C60600 488BBB68"
    rALC668_Stage6="41C60601 488BBB68"
    nALC668_Stage6="AppleHDA"
    #
    # Chrome audio issues patch stage 2 of 2
    #
    cALC668_Stage7="Sleep loose sound issue patch 2 of 2"
    fALC668_Stage7="41C68643 01000000"
    rALC668_Stage7="41C68643 01000001"
    nALC668_Stage7="AppleHDA"
    #
    # Now let's inject it.
    #
    cALC668Data=("$cALC668_Stage1" "$cALC668_Stage2" "$cALC668_Stage3" "$cALC668_Stage4" "$cALC668_Stage5" "$cALC668_Stage6" "$cALC668_Stage7")
    fALC668Data=("$fALC668_Stage1" "$fALC668_Stage2" "$fALC668_Stage3" "$fALC668_Stage4" "$fALC668_Stage5" "$fALC668_Stage6" "$fALC668_Stage7")
    rALC668Data=("$rALC668_Stage1" "$rALC668_Stage2" "$rALC668_Stage3" "$rALC668_Stage4" "$rALC668_Stage5" "$rALC668_Stage6" "$rALC668_Stage7")
    nALC668Data=("$nALC668_Stage1" "$nALC668_Stage2" "$nALC668_Stage3" "$nALC668_Stage4" "$nALC668_Stage5" "$nALC668_Stage6" "$nALC668_Stage7")
    for ((k=0; k<${#nALC668Data[@]}; ++k))
    do
      local gCmp_fString=$(_bin2base64 "$fALC668Data")
      local gCmp_rString=$(_bin2base64 "$rALC668Data")
      if [[ $gClover_kexts_to_patch_data != *"$gCmp_fString"* || $gClover_kexts_to_patch_data != *"$gCmp_rString"* ]];
        then
          #
          # No patch existed in config.plist, add patch for it:
          #
          _kext2patch "${cALC668Data[k]}" "${fALC668Data[k]}" "${rALC668Data[k]}" "${nALC668Data[k]}"
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
    # Whether the Intel Graphics kernel extensions are loaded in cache?
    #
    if [[ `kextstat` == *"Azul"* && `kextstat` == *"HD5000"* ]];
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
    # Patch IOKit?
    #
    if [[ $gHorizontalRez -gt 1920 || $gSystemHorizontalRez -gt 1920 ]];
      then
        #
        # Yes, We indeed require a patch to unlock the limitation of flash rate of IOKit to power up the QHD+/4K display.
        #
        # Note: the argument of gPatchIOKit is set to 0 as default if the examination of resolution fail, this argument can ensure all models being powered up.
        #
        gPatchIOKit=${kBASHReturnSuccess}
      else
        #
        # No, patch IOKit is not required, we won't touch IOKit(for a more intergration/clean system since less is more).
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

function _upd_EFI()
{
    local gUPD=${kBASHReturnSuccess}
    #
    # Update EFI drivers/Clover.
    #
    if [ -f "$1" ];
      then
        local gMD_nd=$(md5 -q "$1")
      else
        local gUPD=${kBASHReturnFailure}
    fi

    #
    # Target EFI/Clover files.
    #
    if [ -f "$2" ];
      then
        local gMD_nd=$(md5 -q "$2")
      else
        local gUPD=${kBASHReturnFailure}
    fi

    if [[ $gMD_st != $gMD_nd && $gUPD == ${kBASHReturnSuccess} ]];
      then
        #
        # Yes, ne, update Clover.
        #
        _tidy_exec "cp "$1" "$2"" "Update $2"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _check_and_fix_config()
{
    #
    # Check if the ig-platform-id is correct(i.e. ig-platform-id = 0x0a2e0008).
    #
    target_ig_platform_id="0x0a2e0008"
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
    #
    # Check SSDT-m-M3800.aml
    #
    local dCheck_SSDT="SSDT-m-M3800.aml"
    local gSortedOrder=$(awk '/<key>SortedOrder<\/key>.*/,/<\/array>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g')
    local gSortedNumber=$(awk '/<key>SortedOrder<\/key>.*/,/<\/array>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g' | wc -l)
    if [[ $gSortedOrder != *"$dCheck_SSDT"* ]];
      then
        #
        # $dCheck_SSDT no found. Insert it.
        #
        ${doCommands[1]} "Add ':ACPI:SortedOrder:' string" ${config_plist}
        ${doCommands[1]} "Set ':ACPI:SortedOrder:$gSortedNumber' $dCheck_SSDT" ${config_plist}
    fi

    #
    # Gain all binary patches from config.
    #
    if [ $gMINOR_VER -lt $gDelimitation_OSVer ];
      then
      #
      # 10.12-, note: this detection will later remove due to optimization.
      #
      gClover_kexts_to_patch_data=$(awk '/<key>KextsToPatch<\/key>.*/,/<\/array>/' ${config_plist})
    fi


    #
    # Repair the lid wake problem for 0x0a2e0008 by syscl/lighting/Yating Zhou.
    #
    cLidWake="Enable lid wake after sleep for 0x0a2e0008 (c) syscl/lighting/Yating Zhou"
    fLidWake="40000000 1e000000 05050901"
    rLidWake="40000000 0f000000 05050901"
    nLidWake="AppleIntelFramebufferAzul"
    #
    # Enable 160MB BIOS, 48MB Framebuffer, 48MB Cursor for Azul framebuffer 0x0a2e0008.
    #
    cAzulFrameBuffer="Enable 160MB BIOS, 48MB Framebuffer, 48MB Cursor for Azul framebuffer 0x0a2e0008"
    fAzulFrameBuffer="08002e0a 01030303 00000004 00002002 00005001"
    rAzulFrameBuffer="08002e0a 01030303 00000008 00000003 00000003"
    nAzulFrameBuffer="AppleIntelFramebufferAzul"
    #
    # Check if "Enable HD4600 HDMI Audio" is located in config.plist.
    #
    cHDMI="Enable HD4600 HDMI Audio"
    fHDMI="3D0C0A00 00"
    rHDMI="3D0C0C00 00"
    nHDMI="AppleHDAController"
    #
    # Check if "BT4LE-Handoff-Hotspot" is in place of kextstopatch.
    #
    cHandoff="Enable BT4LE-Handoff-Hotspot"
    #
    # Check the minor version of OS X(e.g. 10.10 vs. 10.11) and then we can choose the patch accordingly to the system.
    #
    if [[ $gMINOR_VER -ge 11 ]];
      then
        #
        # OS X is 10.11+.
        #
        fHandoff="4885ff74 47488b07"
        rHandoff="41be0f00 0000eb44"
      else
        #
        # OS X is 10.10-.
        #
        fHandoff="4885c074 5c0fb748"
        rHandoff="41be0f00 0000eb59"
    fi
    nHandoff="IOBluetoothFamily"

    if [[ $gMINOR_VER -ge 12 ]];
      then
        #
        # OS X is 10.12+.
        #
        cHaswellLive="Fix Intel HD4600 Safari Video Crash credit vit9696"
        fHaswellLive="48898ba8 000000"
        rHaswellLive="90909090 909090"
        nHaswellLive="AppleIntelFramebufferAzul"
    fi

    #
    # Now let's inject it.
    #
    if [[ $gMINOR_VER -ge 12 ]];
      then
#        cBinData=("$cLidWake" "$cAzulFrameBuffer" "$cHDMI" "$cHandoff" "$cHaswellLive")
#        fBinData=("$fLidWake" "$fAzulFrameBuffer" "$fHDMI" "$fHandoff" "$fHaswellLive")
#        rBinData=("$rLidWake" "$rAzulFrameBuffer" "$rHDMI" "$rHandoff" "$rHaswellLive")
#        nBinData=("$nLidWake" "$nAzulFrameBuffer" "$nHDMI" "$nHandoff" "$nHaswellLive")
        cBinData=("$cLidWake" "$cAzulFrameBuffer" "$cHDMI" "$cHandoff")
        fBinData=("$fLidWake" "$fAzulFrameBuffer" "$fHDMI" "$fHandoff")
        rBinData=("$rLidWake" "$rAzulFrameBuffer" "$rHDMI" "$rHandoff")
        nBinData=("$nLidWake" "$nAzulFrameBuffer" "$nHDMI" "$nHandoff")
      else
        cBinData=("$cLidWake" "$cAzulFrameBuffer" "$cHDMI" "$cHandoff")
        fBinData=("$fLidWake" "$fAzulFrameBuffer" "$fHDMI" "$fHandoff")
        rBinData=("$rLidWake" "$rAzulFrameBuffer" "$rHDMI" "$rHandoff")
        nBinData=("$nLidWake" "$nAzulFrameBuffer" "$nHDMI" "$nHandoff")
    fi

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

      if [ "${RETURN_VAL}" == 0 ];
        then
          DptfTa=SSDT-${index}
      fi
    done

    #
    # Search SaSsdt.
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "SaSsdt" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ];
        then
          SaSsdt=SSDT-${index}
      fi
    done

    #
    # Search SgRef.
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "SgRef" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ];
        then
          SgRef=SSDT-${index}
      fi
    done

    #
    # Search OptRef.
    #
    for ((index = 1; index <= ${number}; index++))
    do
      grep -i "OptRef" "${REPO}"/DSDT/raw/SSDT-${index}.dsl &> /dev/null && RETURN_VAL=0 || RETURN_VAL=1

      if [ "${RETURN_VAL}" == 0 ];
        then
          OptRef=SSDT-${index}
      fi
    done
}

#
#--------------------------------------------------------------------------------
#

function _update_clover()
{
    KEXT_DIR=/Volumes/EFI/EFI/CLOVER/kexts/${gOSVer}

    #
    # Updating kexts. NOTE: This progress will remove any previous kexts.
    #
    _PRINT_MSG "--->: ${BLUE}Updating kexts...${OFF}"
    _tidy_exec "rm -rf ${KEXT_DIR}" "Remove pervious kexts in ${KEXT_DIR}"
    _tidy_exec "cp -R ./CLOVER/kexts/${gOSVer} /Volumes/EFI/EFI/CLOVER/kexts/" "Update kexts from ./CLOVER/kexts/${gOSVer}"
    _tidy_exec "cp -R ./Kexts/*.kext ${KEXT_DIR}/" "Update kexts from ./Kexts"

    #
    # Decide which BT kext to use.
    #
    gBluetooth_Brand_String=$(ioreg | grep -i 'BCM' | grep -i 'Apple' | sed -e 's/.*-o //' -e 's/@.*//')

    #
    # Try to build injector instead of using BrcmPatchRAM.kext
    #
    if [[ `ioreg` == *"BCM20702A3"* ]];
      then
        #
        # BCM20702A3 found.
        #
        _tidy_exec "rm -R ${KEXT_DIR}/BrcmFirmwareRepo.kext" "BCM20702A3 found"
      else
        #
        # BCM2045A0 found. We remove BrcmFirmwareData.kext to prevent this driver crashes the whole system during boot.
        #
        _tidy_exec "rm -R ${KEXT_DIR}/BrcmFirmwareData.kext" "BCM2045A0 found"
    fi

    #
    # Decide which kext to be installed for BT.
    #
    if [[ $gMINOR_VER -ge 11 ]];
      then
        #
        # OS X is 10.11+.
        #
        _tidy_exec "rm -R ${KEXT_DIR}/BrcmPatchRAM.kext" "Remove redundant BT driver::BrcmPatchRAM.kext"
      else
        #
        # OS X is 10.10-.
        #
        _tidy_exec "rm -R ${KEXT_DIR}/BrcmPatchRAM2.kext" "Remove redundant BT driver::BrcmPatchRAM2.kext"
    fi

    #
    # gEFI.
    #
    drvEFI=("FSInject-64.efi" "HFSPlus.efi" "OsxAptioFix2Drv-64.efi" "OsxFatBinaryDrv-64.efi" "DataHubDxe-64.efi")
    efiTOOL=("Shell.inf" "Shell32.efi" "Shell64.efi" "Shell64U.efi" "bdmesg-32.efi" "bdmesg.efi")

    #
    # Check if necessary to update Clover.
    #
    for filename in "${drvEFI[@]}"
    do
      _upd_EFI "${drivers64UEFI}/${filename}" "${t_drivers64UEFI}/${filename}"
    done

    for filename in "${efiTOOL[@]}"
    do
      _upd_EFI "${clover_tools}/${filename}" "${t_clover_tools}/${filename}"
    done

    #
    # Update CLOVERX64.efi
    #
    _upd_EFI "${REPO}/CLOVER/CLOVERX64.efi" "/Volumes/EFI/EFI/CLOVER/CLOVERX64.efi"
}

#
#--------------------------------------------------------------------------------
#

function _update_thm()
{
    if [ -d /Volumes/EFI/EFI/CLOVER/themes/bootcamp ];
      then
        if [[ `cat /Volumes/EFI/EFI/CLOVER/themes/bootcamp/theme.plist` != *"syscl"* ]];
          then
            #
            # Yes we need to update themes.
            #
            _del /Volumes/EFI/EFI/CLOVER/themes/bootcamp
            cp -R ${REPO}/CLOVER/themes/BootCamp /Volumes/EFI/EFI/CLOVER/themes
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
    echo ''                                                                                                                                                 >> "$gUSBSleepScript"
    echo 'diskutil list | grep -i "External" | sed -e "s| (external, physical):||" | xargs -I {} diskutil eject {}'                                         >> "$gUSBSleepScript"
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
    echo 'diskutil list | grep -i "External" | sed -e "s| (external, physical):||" | xargs -I {} diskutil mountDisk {}'                                     >> "$gUSBWakeScript"
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

function _bakBaseSystem()
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
          if [[ $checksum == $gLastOpenedFileMD5 && gStop_Bak != ${kBASHReturnSuccess} ]];
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
    _touch "${gMountPoint}"

    #
    # Gain origin file format(e.g. UDZO...).
    #
    local gBaseSystem_FS=$(hdiutil imageinfo "${gRecoveryHD_DMG}" | grep -i "Format:" | sed -e 's/.*://' -e 's/ //')
    local gTarget_FS=$(echo 'UDRW')

    #
    # Backup origin BaseSystem.dmg to ${REPO}/Backups
    #
    _bakBaseSystem
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
    _PRINT_MSG "--->: Updating Recovery HD for DELL M3800/XPS9530..."
    cp ${gBaseSystem_PATCH} "${gRecoveryHD_DMG}"
    chflags hidden "${gRecoveryHD_DMG}"

    #
    # Clean redundant dmg files.
    #
    _tidy_exec "rm $gBaseSystem_RW $gBaseSystem_PATCH" "Clean redundant dmg files"
    _tidy_exec "diskutil unmount ${gRecoveryHD}" "Unmount ${gRecoveryHD}"
}

#
#--------------------------------------------------------------------------------
#

function main()
{
    #
    # Get argument.
    #
    gArgv=$(echo "$@" | tr '[:lower:]' '[:upper:]')
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

    #
    # Sync all files from https://github.com/syscl/M3800
    #
    # Check if github is available
    #
    if [[ "$gArgv" != *"-NO-UPDATE"* ]];
      then
        _update
    fi

    #
    # Generate dir.
    #
    _tidy_exec "_touch "${REPO}/DSDT"" "Create ./DSDT"
    _tidy_exec "_touch "${prepare}"" "Create ./DSDT/prepare"
    _tidy_exec "_touch "${precompile}"" "Create ./DSDT/precompile"
    _tidy_exec "_touch "${compile}"" "Create ./DSDT/compile"

    #
    # Mount esp.
    #
    diskutil list
    printf "Enter ${RED}EFI's${OFF} IDENTIFIER, e.g. ${BOLD}disk0s1${OFF}"
    read -p ": " targetEFI
    _tidy_exec "diskutil mount ${targetEFI}" "Mount ${targetEFI}"

    #
    # Ensure / Force Graphics card to power.
    #
    _initIntel
    _getEDID

    #
    # Copy origin aml to raw.
    #
    if [ -f /Volumes/EFI/EFI/CLOVER/ACPI/origin/DSDT.aml ];
      then
        _tidy_exec "cp /Volumes/EFI/EFI/CLOVER/ACPI/origin/DSDT.aml /Volumes/EFI/EFI/CLOVER/ACPI/origin/SSDT-*.aml "${decompile}"" "Copy untouch ACPI tables"
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
    # Decompile dsdt.
    #
    cd "${REPO}"
    _PRINT_MSG "--->: ${BLUE}Disassembling tables...${OFF}"
    _tidy_exec ""${REPO}"/tools/iasl -w1 -da -dl "${REPO}"/DSDT/raw/DSDT.aml "${REPO}"/DSDT/raw/SSDT-*.aml" "Disassemble tables"

    #
    # Search specification tables by syscl/Yating Zhou.
    #
    _tidy_exec "_find_acpi" "Search specification tables by syscl/Yating Zhou"

    #
    # DSDT Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching DSDT.dsl${OFF}"
    _tidy_exec "patch_acpi DSDT syntax "fix_PARSEOP_ZERO"" "Fix PARSEOP_ZERO"
    _tidy_exec "patch_acpi DSDT syntax "fix_ADBG"" "Fix ADBG Error"
    _tidy_exec "patch_acpi DSDT graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"
    _tidy_exec "patch_acpi DSDT usb "usb_7-series"" "7-series/8-series USB"
    _tidy_exec "patch_acpi DSDT usb "usb_prw_0x0d_xhc"" "Fix USB _PRW"
    _tidy_exec "patch_acpi DSDT battery "battery_Acer-Aspire-E1-571"" "Acer Aspire E1-571"
    _tidy_exec "patch_acpi DSDT system "system_IRQ"" "IRQ Fix"
    _tidy_exec "patch_acpi DSDT system "system_SMBUS"" "SMBus Fix"
    _tidy_exec "patch_acpi DSDT system "system_ADP1"" "AC Adapter Fix"
    _tidy_exec "patch_acpi DSDT system "system_MCHC"" "Add MCHC"
    _tidy_exec "patch_acpi DSDT system "system_WAK2"" "Fix _WAK Arg0 v2"
    _tidy_exec "patch_acpi DSDT system "system_IMEI"" "Add IMEI"
    _tidy_exec "patch_acpi DSDT system "system_Mutex"" "Fix Non-zero Mutex"
    _tidy_exec "patch_acpi DSDT syscl "system_OSYS"" "OS Check Fix"
    _tidy_exec "patch_acpi DSDT syscl "audio_HDEF-layout1"" "Add audio Layout 1"
    _tidy_exec "patch_acpi DSDT syscl "audio_B0D3_HDAU"" "Rename B0D3 to HDAU"
    _tidy_exec "patch_acpi DSDT syscl "remove_glan"" "Remove GLAN device"
    _tidy_exec "patch_acpi DSDT syscl "syscl_iGPU_MEM2"" "iGPU TPMX to MEM2"
    _tidy_exec "patch_acpi DSDT syscl "syscl_IMTR2TIMR"" "IMTR->TIMR, _T_x->T_x"
#   _tidy_exec "patch_acpi DSDT syscl "syscl_ALSD2ALS0"" "ALSD->ALS0"

    #
    # DptfTa Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${DptfTa}.dsl${OFF}"
    _tidy_exec "patch_acpi ${DptfTa} syscl "_BST-package-size"" "_BST package size"
    _tidy_exec "patch_acpi ${DptfTa} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"

    #
    # SaSsdt Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${SaSsdt}.dsl${OFF}"
    _tidy_exec "patch_acpi ${SaSsdt} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"
    _tidy_exec "patch_acpi ${SaSsdt} syscl "syscl_Iris_Pro"" "Rename HD4600 to Iris Pro"
    _tidy_exec "patch_acpi ${SaSsdt} graphics "graphics_PNLF_haswell"" "Brightness fix (Haswell)"
    _tidy_exec "patch_acpi ${SaSsdt} syscl "audio_B0D3_HDAU"" "Rename B0D3 to HDAU"
    _tidy_exec "patch_acpi ${SaSsdt} syscl "audio_Intel_HD4600"" "Insert HDAU device"

    #
    # SgRef Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${SgRef}.dsl${OFF}"
    _tidy_exec "patch_acpi ${SgRef} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"

    #
    # OptRef Patches.
    #
    _PRINT_MSG "--->: ${BLUE}Patching ${OptRef}.dsl${OFF}"
    _tidy_exec "patch_acpi ${OptRef} syscl "WMMX-invalid-operands"" "Remove invalid operands"
    _tidy_exec "patch_acpi ${OptRef} graphics "graphics_Rename-GFX0"" "Rename GFX0 to IGPU"
    _tidy_exec "patch_acpi ${OptRef} syscl "graphics_Disable_Nvidia"" "Disable Nvidia card (Non-operational in OS X)"

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
    _tidy_exec "compile_table "${SgRef}"" "Compile SgRef"
    _tidy_exec "compile_table "${OptRef}"" "Compile OptRef"

    #
    # Copy SSDT-rmne.aml.
    #
    _PRINT_MSG "--->: ${BLUE}Copying SSDT-rmne.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-rmne.aml "${compile}"" "Copy SSDT-rmne.aml to ./DSDT/compile"

    #
    # Detect which SSDT for processor to be installed.
    #
    if [[ `sysctl machdep.cpu.brand_string` == *"i7-4702HQ"* ]];
      then
        _tidy_exec "cp "${prepare}"/CpuPm-4702HQ.aml "${compile}"/SSDT-pr.aml" "Generate C-States and P-State for Intel ${BLUE}i7-4702HQ${OFF}"
    fi

    if [[ `sysctl machdep.cpu.brand_string` == *"i7-4712HQ"* ]]
      then
        _tidy_exec "cp "${prepare}"/CpuPm-4712HQ.aml "${compile}"/SSDT-pr.aml" "Generate C-States and P-State for Intel ${BLUE}i7-4712HQ${OFF}"
    fi

    if [[ `sysctl machdep.cpu.brand_string` == *"i5-4200H"* ]]
      then
        _tidy_exec "cp "${prepare}"/CpuPm-4200H.aml "${compile}"/SSDT-pr.aml" "Generate C-States and P-State for Intel ${BLUE}i5-4200H${OFF}"
    fi

    #
    # Install SSDT-m for ALS0.
    #
    _PRINT_MSG "--->: ${BLUE}Installing SSDT-m-M3800.aml to ./DSDT/compile...${OFF}"
    _tidy_exec "cp "${prepare}"/SSDT-m-M3800.aml "${compile}"" "Copy SSDT-m-M3800.aml to ./DSDT/compile"

    #
    # Clean up dynamic SSDTs.
    #
    _tidy_exec "rm "${compile}"SSDT-*x.aml" "Clean dynamic SSDTs"

    #
    # Copy AML to destination place.
    #
    _tidy_exec "_touch "/Volumes/EFI/EFI/CLOVER/ACPI/patched"" "Create /Volumes/EFI/EFI/CLOVER/ACPI/patched"
    _tidy_exec "cp "${compile}"*.aml /Volumes/EFI/EFI/CLOVER/ACPI/patched" "Copy tables to /Volumes/EFI/EFI/CLOVER/ACPI/patched"

    #
    # Refresh kext in Clover.
    #
    _update_clover

    #
    # Refresh BootCamp theme.
    #
    _update_thm

    #
    # Install audio.
    #
    _PRINT_MSG "--->: ${BLUE}Installing audio...${OFF}"
    _tidy_exec "install_audio" "Install audio"

    #
    # Patch IOKit/CoreDisplay.
    #
    _PRINT_MSG "NOTE: Set ${BOLD}System Agent (SA) Configuration—>Graphics Configuration->DVMT Pre-Allocated->${RED}『160MB』${OFF}"

    if [ $gPatchIOKit -eq 0 ];
      then
        #
        # Patch IOKit.
        #
        _PRINT_MSG "--->: ${BLUE}Unlocking maximum pixel clock...${OFF}"
        if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
          then
            #
            # 10.12+
            #
            gTarget_Framework_Repo="/System/Library/Frameworks/CoreDisplay.framework/Versions/Current/CoreDisplay"
          else
            #
            # 10.12-
            #
            gTarget_Framework_Repo="/System/Library/Frameworks/IOKit.framework/Versions/Current/IOKit"
        fi
            sudo perl -i.bak -pe 's|\xB8\x01\x00\x00\x00\xF6\xC1\x01\x0F\x85|\x33\xC0\x90\x90\x90\x90\x90\x90\x90\xE9|sg' ${gTarget_Framework_Repo}
            _tidy_exec "sudo codesign -f -s - ${gTarget_Framework_Repo}" "Patch and sign framework"
    fi

    #
    # Lead to lid wake on 0x0a2e0008 by syscl/lighting/Yating Zhou.
    #
    _PRINT_MSG "--->: ${BLUE}Leading to lid wake on 0x0a2e0008 (c) syscl/lighting/Yating Zhou...${OFF}"
    _tidy_exec "_check_and_fix_config" "Lead to lid wake on 0x0a2e0008"

    #
    # Fix issue that external devices ejected improperly upon sleep (c) syscl/lighting/Yating Zhou.
    #
    _fix_usb_ejected_improperly

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
    _PRINT_MSG "--->: ${BLUE}Rebuilding kernel extensions cache...${OFF}"
    _tidy_exec "rebuild_kernel_cache" "Rebuild kernel extensions cache"

    #
    # Clean up backup
    #
    _del /Volumes/EFI/EFI/CLOVER/config.plistg

    _PRINT_MSG "NOTE: Congratulations! All operation has been completed"
    _PRINT_MSG "NOTE: Reboot now. Then enjoy your OS X! -${BOLD}syscl/lighting/Yating Zhou @PCBeta${OFF}"
}

#==================================== START =====================================

main "$@"

#================================================================================

exit ${RETURN_VAL}
