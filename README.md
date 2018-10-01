
macOS on DELL XPS13 (9350)
====================================
This project targets at giving the relatively complete functional macOS for XPS13 9350. Before you start, there's a brief introduction of how to finish powering up macOS on your laptop:

#### Peculiarities
Since the original WiFi module is not compatible with macOS, you need to buy a DW1830 or DW1560 module.
Please follow this [guide](https://www.ifixit.com/Teardown/Dell+XPS+13+Teardown/36157) to swap it.

#### Preliminary
1. Create a vanilla installation disk (USB or other removable disk). (Google how to)
2. Install Clover with UEFI only and UEFI64Drivers to the installation disk just created.
3. Replace the original CLOVER folder with the one under my Git/XPS9350-macOS/CLOVER.
4. Change BIOS settings to the following
  * Disable Secure Boot
  * Set SATA Operation to AHCI
5. Boot to USB and hit F4 and/or Fn-F4 to capture ACPI tables to the USB
6. Install macOS but do not reboot until you have finished steps 7 and 8, below.
7. Install Clover with UEFI only and UEFI64Drivers to SSD.
8. Replace the original CLOVER folder on the SSD with the one from the USB drive under my Git/XPS9350-macOS/CLOVER.
9. Once you finish installation of macOS, you can do the following steps to finish the post installation of macOS


#### Installation
Download the latest version installation package/directory by entering the following command in a terminal window:

```sh
git clone --recursive https://github.com/syscl/XPS9350-macOS
```
This will download the whole installation directory to your current directory(./) and the next step is to change the permissions of the file (add +x) so that it can be run.


```sh
cd XPS9350-macOS
chmod +x ./Deploy.sh
```


Run the script in a terminal windows by(Note: You should dump the ACPI tables by pressing F4/Fn+F4 under Clover first and then execute the following command lines):

```sh
./Deploy.sh
```

Reboot your macOS to see the change. If you have any problem about the script, try to run deploy in DEBUG mode by 
```sh
./Deploy.sh -d
```

#### Contribution
All suggestions and improvements are welcome, don't hesitate to pull request or open an issue if you want this project to be better than ever.
Writing and supporting code is fun but it takes time. Please provide most descriptive bugreports or pull requests.

#### To do list
Try to get rid of scripting procedure, use dynamic ACPI hot patch

#### Change Log
[Change logs](https://github.com/syscl/XPS9350-macOS/blob/master/Changelog.md) for detail improvements

