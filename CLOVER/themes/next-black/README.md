# Clover Next Black
A clean theme for [the Clover UEFI bootloader](http://sourceforge.net/projects/cloverefiboot), based off [rEFInd Next Theme by sdbinwiiexe](http://www.deviantart.com/art/rEFInd-Next-Theme-407754566) and inspired by [rEFInd-Black by st-andrew](https://github.com/st-andrew/rEFInd-Black).

![Screenshot of the theme](http://i.imgbox.com/1CER9jT7.png)

## Installation
Clone or download the ZIP of this repo to your Clover theme directory (usually in /EFI/CLOVER/themes, located on the EFI system partition). Then, edit your Clover config.plist to select the theme.
```plist
<key>GUI</key>
<dict>
	<key>Theme</key>
	<string>clover-next-black</string>
</dict>
```
By default, labels for the boot entries are hidden. If you would like to enable them, you can edit the theme.plist file in this repo by changing the `Banner` key to `true`.
```plist
<key>Components</key>
<dict>
	<key>Banner</key>
  <false/>
	<key>Functions</key>
	<true/>
	<key>Label</key>
	<true/>
	<key>Revision</key>
	<false/>
	<key>MenuTitle</key>
	<true/>
</dict>
```

Special thanks to sdbinwiiexe for his original theme. Thanks to xenatt for the cursor icon and the font image.
