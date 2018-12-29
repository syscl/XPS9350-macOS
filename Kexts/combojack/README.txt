Hackintosh combojack support for alc256/alc255.
Confirmed to work on dell xps 13 9350/9360(alc256) and Xiaomi Air(i5-7200U, alc255)
1. Delete CodecCommander.kext，put ComboJack_Installer/VerbStub.kext in Clover/kexts/Other
2. Run ComboJack_Installer/install.sh in terminal and reboot
3. Done. When you attach a headphone there will be a popup asking about headphone type.

黑苹果上alc256/alc255的耳麦支持
在xps 13 9350/9360(alc256)和小米Air(i5-7200U, alc255)上测试可用
1. 删除 CodecCommander.kext，把ComboJack_Installer文件夹的VerbStub.kext放进Clover/kexts/Other
2. 终端运行 ComboJack_Installer/install.sh，重启
3. 插入耳机的时候，会弹出对话框询问你插入的是耳机还是耳塞
