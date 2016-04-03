automount2
==========

This "tools" helps you auto-mount a usb flash storage or hard disk, especially when you are using Raspberry pi without a monitor and keyboard.

How To
-------

Before you use it, You may open those files and have a look.

1. First step, set the files at the right place 
```bash
~$ sudo cp automount2.sh /opt
~$ sudo chmod 0755 /opt/automount2.sh
~$ sudo cp 99-automount.rules /etc/udev/rules.d
~
```

2. You may need to reload udev rules.
```bash
~$ sudo sudo udevadm control --reload
```


3. You plug in your usb drive to your Raspberry pi 2 and take a look at `/media`.
```bash
~$ ls /media -al
```


Known issue
-----------

If your usb drive is formatted NTFS, Oh , This script will not work as we expected.
```
@RaspberryPi-2:~$ lsblk
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    1 29.7G  0 disk /media/Teclast 32G
sdb           8:16   1  3.7G  0 disk /media/NTFS Volume
mmcblk0     179:0    0 14.9G  0 disk
├─mmcblk0p1 179:1    0  100M  0 part /boot
└─mmcblk0p2 179:2    0 14.8G  0 part /
@RaspberryPi-2:~$ ls /media -l
ls: cannot access '/media/NTFS Volume': Transport endpoint is not connected
total 4
d????????? ? ?      ?          ?            ? NTFS Volume
drwxrwxrwx 6 nobody nogroup 4096 Apr  3 22:46 Teclast 32G

``` 

Because [FileSystem in Userapace, FUSE](https://zh.wikipedia.org/zh-cn/FUSE) seems not work when you mount it by udev.


That's all.
