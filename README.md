OS X on DELL M3800 and XPS15 (9530)
====================================


This project targets at giving the relatively complete functional OS X for both Dell Precision M3800 and XPS15 9530. Before you start, there's a brief introduction of how to finish powering up OS X on your laptop:

1. Create a vanilla installation disk(removable disk).
2. Install Clover with UEFI only and UEFI64Drivers to the installation disk just created. 
3. Replace the origin Clover folder with the one under my Git/M3800/CLOVER.
4. Patch bios to unlock bios menu.
5. BIOS settings:
```sh
- Advanced:
    CPU Configuration/CFG Lock = Disabled
    CPU Configuration/LakeTiny Feature = Enabled

    SATA Operation = AHCI 

- Chipset:
    PCH-IO Configuration/XHCI Mode = Smart Auto

    System Agent (SA) Configuration/Graphics Configuration:
        Aperture Size = 512MB
        DVMT Pre-Allocated = 160MB
        DVMT Total Gfx Mem = MAX
NOTE: Once you modify your settings in BIOS(especially Graphics Configuration in SA), you have to remove previous ACPI tables first, redump ACPI tables by press Fn+F4/F4 under Clover, and run deploy.sh again to patch your ACPI tables again.
```
6. Install OS X.
7. Once you finish installation of OS X, you can do the following steps to finish the post installation of OS X.

How to use deploy.sh?
----------------

Download the latest version installation package/directory by entering the following command in a terminal window:

```sh
git clone https://github.com/syscl/M3800
```
This will download the whole installation directory to your current directory(./) and the next step is to change the permissions of the file (add +x) so that it can be run.


```sh
chmod +x ./M3800/deploy.sh
```


Run the script in a terminal windows by(Note: You should dump the ACPI tables by pressing F4/Fn+F4 under Clover first and then execute the following command lines):

```sh
cd M3800
./deploy.sh
```

Reboot your OS X to see the change. If you have any problem about the script, try to run deploy in DEBUG mode by 
```sh
./deploy.sh -d
```

Note: For two finger scrolling you need to change the speed of the Scrolling once to get it work and also have to enable them in Trackpad preferences.

Change Log
----------------
2016-10-27

- Fix Intel Haswell HD Video for Safari on Sierra credit vit9696

2016-10-26

- macOS 10.12.1 fixed all keyboard function keys(brightness up/down, volume up/down), please update to the latest version 
- macOS 10.12 fixed the System Preference-->Sound-->Output cause headphone noise issue
- Updated SmartTouchPad config with 3D Touch function by syscl
- Removed useless boot glitches patch on 10.12.x to prevent 3 stage logo change. Actually, Apple seems to fix almost the boot glitch issue for us. Cheers!
- Updated Clover to r3859
- Ready for IOPowerManagement to be released, please wait this week:)

2016-10-10

- Updated Clover to r3793:
- Introduce SMCHelper efi driver
- Fix zero pointer dereferencing

2016-10-4

- Updated AppleHDA patches on 10.12.x credit @PMHeart (aka) Vanilla

2016-10-1

- Added UHD patched BIOS for XPS9530 credit @ssmith353 see [here] (https://github.com/syscl/M3800/issues/22).

2016-9-15

- Mount points at wake to fix external hard disk mounting issue.
- Updated AppleALC to 1.0.16 with bug fix:
- Fixed a rare kernel panic on initialisation failure
- Fixed a rare lock acquisition issue on 10.12
- Fixed an undefined behaviour when failing to perform an i/o operation
- Guaranteed null termination for readFileToBuffer buffers

2016-7-17

- Added Backup checksum detection to prevent too many backup files
being created.
- Added pixel unlock for Sierra support.
- Optimised code.

2016-7-15

- Added SMC Version (system) and smc-huronriver for FakeSMC.kext.
- Updated Clover to r3625.

2016-6-24

- Replaced FakeSMC with slice's one for further 10.12 support.
- Updated Clover to r3556 for further 10.12 support.
- Updated AppleALC with my modification and optimisation for M3800/XPS9530.

2016-6-12

- Added i5-4200H model support credit busymilk for his [hint] (https://github.com/syscl/M3800/issues/25) reminding me that there's i5 model existed in M3800/XPS9530. 

2016-6-10

- New patch for DSDT to fix MEM2 issue and also rename TPMX to MEM2 credit syscl.
- Drop MCFG table and drop DMAR table.
- Auto correct/add SSDT-m-M3800.aml in config.plist. 
- Added UHD patched BIOS for M3800 credit @ssmith353 see [here] (https://github.com/syscl/M3800/issues/22).
- Added SSDT-m for injecting ALS0.

2016-5-27

- Fixed HiDPI(QHD+/UHD) Recovery HD by setting BooterConfig = 0x2A(0x00101010).

2016-5-25

- Huge update for the support of Recovery HD for DELL M3800/XPS9530 (c) syscl/lighting/Yating Zhou.
- Reverted back to Clover injection for ig-platform-id(easier to turn off "Inject Intel" under Graphics for update).

2016-5-15

- Fixed sleep watcher dir issue due to permission. 

2016-5-14

- Added FixRegions argv. The presence of floating regions make impossible to use custom DSDT because this region may be shifted and will not correspond to current state. This patch is intended to find all such regions in BIOS and correct them in custom DSDT. (To prevent potential issues.)
- Updated Clover to r3526.
- Minor bug fixes.
- Sync config.plist to fit the latest standard one.

2016-5-12

- Fixed the touchpad sleep issue due to the latest SmartTouchPad driver.

2016-5-10

- Fixed USB Wi-Fi sleep issue. 
- Sync Fix-usb-sleep.sh to latest version 2016-4-18. 

2016-5-06

- Natural 4fingers action(left/right).
- Optimised deploy.sh structure.
- Fixed an issue that trackpad will sometimes lose respone due to the new function of SmartTouchPad.

2016-4-29

- Added small utility for developers(Use ./M3800/tools/rebuild to rebuild kernel cache easily).
- Updated ./M3800/tools/cleanup for developers.

2016-4-29

- Added small utility for developers(Use ./M3800/tools/rebuild to rebuild kernel cache easily).
- Updated ./M3800/tools/cleanup for developers.

2016-4-28

- Implemented touchpad with 3D Touch/Force Touch: now 2/3 finger long press/touch/pinch will trigger the "look up"/preview function. Really amazing/powerful function!
- 3f swipe: left swipe = backward, right swipe = forward.
- 4f swipe: left swipe = previous application, right swipe = next application.
- Updated SmartTouchPad to 4.6 to fix some issues.
- Added DataHubDxe-64.efi which is DataHub protocol support obligatory for OS X.
- Updated Clover to r3489 to prevent clover writing argvs to nvram during each boot.

2016-4-22

- Updated Clover to r3438.

2016-4-18

- Moved ig-platform-id=0x0a2e0008 to ACPI tables(Fast and reliable injection).
- Cleaned up clover patches.
- Updated FakePCI_ID.kext to 2016-4-14.

2016-4-13

- Fixed the permission issue for sysclusbfix.sleep.
- No more reboot required, the fix will take effect instantly after executing the fixusb.sh!
- Added uninstall function for fixusb.sh.

2016-4-6

- Remove "Welcome to Clover... Scan Entries" by argv "NoEarlyProgress=Yes".
- Moved CodecCommander.kext to Clover folder, a totally vanilla root directory "/".(The same as real Mac's OS X).
- Added support for DELL 1820A wireless & bluetooth.
- Deploy.sh can now update your Clover folder automatically.
- Updated theme for a more clear GUI during clover counting down.
- Updated Clover to 3411.

2016-4-5

- Added debug mode for deploy.sh. Usage:
```sh
./deploy.sh -d
```
or
```sh
./deploy.sh -debug
```
- Fixed the Apple_ALC668.kext problem that will prevent AppleHDA.kext from loading at startup. (Actually remove it)
- Removed redundant resource files in AppleALC.kext and rebuild it to boost the booting progress. (Size 848KB->345KB)

2016-4-4

- vit9696 has updated M3800/XPS15(9530) ALC668 with my configdata. see [here] (https://github.com/vit9696/AppleALC/commit/878c2083497262938eeb2b406de5daac699f571b)

2016-4-3

- Using a totally new way(insert pre-linked-kext at the startup stage to power up the audio which means the only unsigned kernel extension we have to install under /L\*/E\* is CodecCommander.kext to prevent noise from headphone! (Now, we don't have to worry full SIP eanble!!) credit vit9696's great project "dynamic AppleHDA patching" and syscl to modify the configuration for both M3800 and XPS15(9530).
- Fixed an issue that light indicator of front facing camera will not turn off after accessing it (c) syscl/lighting/Yating Zhou.

2016-3-30

- Added the latest version of DisplayLink kext for enable the power of usb3.0 docking station on DELL Precsion M3800/XPS 15(9530).

2016-3-19

- Used "eject" command line to boost the mount disk progress upon sleep, faster than ever! No more external devices lost upon sleep. (c) syscl/lighting/Yating Zhou

2016-3-18

- Fixed issue that external devices ejected improperly upon resume from sleep credit syscl/lighting/Yating Zhou. (More details should be found [here] (https://github.com/syscl/Fix-usb-sleep). 

2016-3-13

- Added magic number "01470c02" as PMheart/neycwcy10's suggestion to try to fix the issue #10.
- Refined configdata from dump codec from linux.
- Enable BT4LE-Handoff-Hotspot by kextstopatch.

2016-3-11

- Finally, M3800/XPS15(9530) can use ig-platform-id 0x0a2e0008(OS Version >= 10.10.2) with the lid wake function after sleep(credit syscl/lighting/Yating Zhou).
- Huge style change! We don't have to reboot 2x due to the change of ig-platform-id! Once you update your OS X(do not reboot), and run the deploy.sh again, then, you can enjoy every functions of OS X you want.
- If you have sound card problem, run the deploy.sh again and reboot to see if it can fix the problem.
- Removed FakePCIID_Intel_HDMI_Audio.kext since we have a better way to power up the HDMI audio.

2016-3-6

- Added 4K(3840 x 2160) support for M3800 credit SimplyLab(see issue #6).
- Changed config.plist/Graphics/Inject/Intel = false to fix installation stucks at booting stage.(Wait for feedback).
- Changed config.plist/KernelAndKextPatches/KextsToPatch/AppleIntelFramebufferAzul for enabling port 0x05 DP to HDMI (87000000 - > 06000000). 

2016-2-17

- Improved the configuration of ApplePS2SmartTouchPad.kext/Contents/config.plist and ApplePS2SmartTouchPad.kext/Contents/PlugIns/ApplePS2Keyboard.kext/Contents/config.plist:
- Set FinerFnBrightnessControl = NO and FinerFnVolumeControl = NO such that Keyboard performs/mute brightness and volume as OS X.
- 3 finger swipe up = Open Mission Control.
- 3 finger swipe down = Open Launchpad.
- 3 finger swipe left = Switch Previous Application.
- 3 finger swipe right = Switch Next Application. 
- 4 finger swipe up = Hide all Windows/Applications.
- 4 finger swipe down = Hide current Window/Application.
- 4 finger swipe left = Back.
- 4 finger swipe right = Go.
- 4 finger pinch = Open Mission Control.
- 5 finger pinch = Open Dashboard.
- My next step is going to find more details of touchpad of M3800/XPS9530 under Linux to make the ApplePS2SmartTouchPad.kext more comfortable to use than ever(Coming soon!).
- Another problem is that after a full sleep, I can't reproduce the fix I made to fix the HP lose sound problem after a cold boot, really boring since I usually plug in HP all the time. I'm finding new way to fix this annoying problem. (After extensive explore, I believe this bug is produced by AppleHDA, since there's no such problem under Windows and Linux. Actually, Linux has this bug, but it can be fixed through a re-plugged-in HP.)


2016-2-12

- Solve the injected headphone will lose sound problem after a cold boot. (syscl)
- Sync vbourachot's repo to fix the headphone distortion (credit vbourachot)


2016-2-5

- Improve the compatibility of the executive script: This change / improvement allows the script to patch the OS X again while the patches of Dell Precision M3800 (3200 x 1800) will fail due to Graphics kexts fail to load.


2016-2-4

- Fixed a major problem that cause the ACPI tables patch fail.
- Use UUID to locate the EFI partition instead of IDENTIFER that may change after reboot.

2015-12-25

- Huge change in deploy.sh, added function method to make the script easy to read, and yes, the script is faster than ever.


2015-12-24

- Fixed typo that will cause AUDIO do not work properly.
- Added new installation guide and clean operation for model of 1920 x 1080p.
- Updated new bluetooth drivers to solve failure of searching bluetooth devices in some cases for all platforms of OS X. 


2015-12-23

- Added new Touchpad/Trackpad driver with zoom for M3800/XPS9530.
- Removed VoodooPS2Controller.kext to avoid function abnormally in some special cases.
- Fixed typo in README.md.
- Updated style of README.md.


2015-12-10

- Added support for 1920*1080p model(Don't worry about the progress, detection will be automatical).
- Refined scripts (Runing more smooth).
- Easier to read.
- Removed ACPIBacklight.kext in ~/M3800/CLOVER/Kexts/10.11
- Fixed minor bugs.
- Revised README.md.


2015-12-9

- Fixed iasl counld not find problem.
- Added auto update function.


2015-12-7 

- Merged two scripts into one : easier to use than before.
- Added permission for two kernel extensions to solve problem known as no audio after installation.
- Boosted the speed of the script.
- Updated VoodooPS2Controller.kext to 11-28.
- Updated CodecCommander.kext to 11-22.
- Used BrcmBluetoothInjector.kext in place of BrcmPatchRAM.kext to drive bluetooth in a more precise way.
- Removed ACPIBacklight.kext. 


2015-11-17 

- Added A10 bios file and flash tools(AFU).
- Bumped version of Clover to v3320.
- Removed "Scan Entiries ..." to boost the progress of booting operation system.
- Updated Config.plist
