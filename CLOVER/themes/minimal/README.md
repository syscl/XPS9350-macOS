# Clover Minimal Theme
A clean theme for [the Clover UEFI bootloader](http://sourceforge.net/projects/cloverefiboot), based off [rEFInd-minimal by Evan Purkhiser](https://github.com/EvanPurkhiser/rEFInd-minimal).

![Screenshot of the theme](http://i.imgbox.com/4gssLdSI.png)

### Installation
Clone or download the ZIP of this repo to your Clover theme directory (usually in /EFI/CLOVER/themes, located on the EFI system partition). Then, edit your Clover config.plist to select the theme.
```plist
<key>GUI</key>
<dict>
	<key>Theme</key>
	<string>clover-theme-minimal</string>
</dict>
```
By default, labels for the boot entries are hidden. If you would like to enable them, you can edit the theme.plist file in this repo by changing the `Label` key to `true`.
```plist
<key>Components</key>
<dict>
	<key>Banner</key>
	<false/>
	<key>Functions</key>
	<true/>
	<key>Label</key>
	<true/>
	<key>MenuTitle</key>
	<true/>
	<key>Revision</key>
	<false/>
</dict>
```

### Credits

Special thanks to Evan Purkhiser for his original theme, which uses OS icons from SWOriginal. Thanks to Ukr55 for the cursor icon, the font image, and some of the tool icons.
