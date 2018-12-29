#!/bin/bash
cd `dirname $0`

xcodebuild -configuration Release || exit 1
rm -f ../ComboJack_Installer/ComboJack
rm -f ../ComboJack_Installer/Headphone.icns
rm -f ../ComboJack_Installer/l10n.json
cp -f build/Release/ComboJack ../ComboJack_Installer/
cp -f ./Headphone.icns ../ComboJack_Installer/
cp -f ./l10n.json ../ComboJack_Installer/
#exec ./build/Release/ComboJack
rm -rf ./build
exec bash ../ComboJack_Installer/install.sh
