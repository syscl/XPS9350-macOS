
macOS on DELL XPS13 (9350)
====================================


This project targets at giving the relatively complete functional macOS for XPS13 9350. Before you start, there's a brief introduction of how to finish powering up macOS on your laptop:

1. Create a vanilla installation disk(removable disk).
2. Install Clover with UEFI only and UEFI64Drivers to the installation disk just created. 
3. Replace the origin Clover folder with the one under my Git/XPS9350-macOS/CLOVER.
4. BIOS settings:
- AHCI instead of AHCI RAID
5. Install macOS
6. Once you finish installation of macOS, you can do the following steps to finish the post installation of macOS


How to use deploy.sh?
----------------

Download the latest version installation package/directory by entering the following command in a terminal window:

```sh
git clone https://github.com/syscl/XPS9350-macOS
```
This will download the whole installation directory to your current directory(./) and the next step is to change the permissions of the file (add +x) so that it can be run.


```sh
chmod +x ./XPS9350-macOS/deploy.sh
```


Run the script in a terminal windows by(Note: You should dump the ACPI tables by pressing F4/Fn+F4 under Clover first and then execute the following command lines):

```sh
cd XPS9350-macOS
./deploy.sh
```

Reboot your macOS to see the change. If you have any problem about the script, try to run deploy in DEBUG mode by 
```sh
./deploy.sh -d
```

Note: For two finger scrolling you need to change the speed of the Scrolling once to get it work and also have to enable them in Trackpad preferences.


TODO List
----------------

Next week I have 3 ```final exams```, so I will be back in next Wednesday! What I will do next week are listed below

- Add reboot fix ```ResetAddress = 0xB2``` and ```ResetValue = 0x73``` to script using auto detection from FACP table
- Refine ACPI patches such that all XPS 13 9350 users can enjoy(still in progress)
- Refine AppleHDA 
- New FixUSB.sh to fix a bug that external devices will disappear when cold boot into macOS
- Import IOPowerManagement
- ACPI Keyboard



Change Log
----------------
2016-12-04

- Fixed boot issue by ```AddClockID``` and ```FixOwnership```

2016-12-01

- Inject PMCR then macOS will combine PPMC together to make AppleIntelPCHPMC load correctly credit syscl

2016-11-29

- Fixed reboot unstable issue and speed up reboot progress ```ResetAddress = 0xB2``` and ```ResetValue = 0x73``` credit syscl

2016-11-22

- Added lspci to list all pci devices

2016-11-20

- Correct SKL laptops' internal display connector type from LVDS to eDP credit syscl
- Added lid wake auto patches for deploy.sh
- Inject SSDT-XPS13SKL.aml

2016-11-19

- PPMC -> PMCR
- Insert DMAC for macOS credit syscl
- Make Device (MATH) load correctly credit syscl
- SBTN -> SLPB with _STA 0x0B credit syscl
- Eliminate SgRef

2016-11-18

- Fixed HD520 glitches on Sierra credit Pikeralpha 
- Eliminate redundant acpi table & patches

2016-11-17

- Fixed brightness save issue: EmuVariableUefi-64 + IntelBacklight + /nvram.plist

2016-11-15

- Fixed screen blank when resume from sleep credit syscl/lighting/Yating Zhou

2016-11-12

- First commit 

