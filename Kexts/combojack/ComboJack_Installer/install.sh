#!/bin/bash
cd `dirname $0`

# Clean legacy stuff
#
sudo launchctl unload /Library/LaunchDaemons/com.XPS.ComboJack.plist
sudo rm -rf /Library/Extensions/CodecCommander.kext
sudo rm /usr/local/bin/ALCPlugFix
sudo rm /Library/LaunchAgents/good.win.ALCPlugFix
sudo rm /Library/LaunchDaemons/good.win.ALCPlugFix
sudo rm /usr/local/sbin/hda-verb
sudo rm /usr/local/share/ComboJack/Headphone.icns
sudo rm /usr/local/share/ComboJack/l10n.json

# install 
mkdir -p /usr/local/sbin
sudo cp ComboJack /usr/local/sbin
sudo chmod 755 /usr/local/sbin/ComboJack
sudo chown root:wheel /usr/local/sbin/ComboJack
sudo cp hda-verb /usr/local/sbin
#sudo chmod 755 /usr/local/sbin/hda-verb
#sudo chown root:wheel /usr/local/sbin/hda-verb
sudo mkdir -p /usr/local/share/ComboJack/
sudo cp Headphone.icns /usr/local/share/ComboJack/
sudo chmod 644 /usr/local/share/ComboJack/Headphone.icns
sudo cp l10n.json /usr/local/share/ComboJack/
sudo chmod 644 /usr/local/share/ComboJack/l10n.json
sudo cp com.XPS.ComboJack.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.XPS.ComboJack.plist
sudo chown root:wheel /Library/LaunchDaemons/com.XPS.ComboJack.plist
sudo launchctl load /Library/LaunchDaemons/com.XPS.ComboJack.plist
echo
echo "Please reboot! Also, it may be a good idea to turn off \"Use"
echo "ambient noise reduction\" when using an input method other than"
echo "the internal mic (meaning line-in, headset mic). As always: YMMV."
echo
echo "You can check to see if the watcher is working in the IORegistry:"
echo "there should be a device named \"VerbStubUserClient\" attached to"
echo "\"com_XPS_SetVerb\" somewhere within the \"HDEF\" entry's hierarchy."
echo
echo "Enjoy!"
echo
exit 0
