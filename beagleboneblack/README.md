# BeagleBone Black (BBB) related stuffs

  - [create_keyboard.sh](create_keyboard.sh) --- creates USB Gadget device.
  - [send_functions.sh](send_functions.sh) --- collection of shell functions
  - [send_line.sh](send_line.sh) --- sends string arguments, separated by a space and terminated by newline.


## BBB as scriptable keyboard

You can make BBB into a scriptable keyboard using USB Gadget driver.  This means,
you can send out "key presses" from USB device port (mini-USB).  From USB host side,
it appears just like another keyboard.

Original work was done by Phil Polstra (@ppolstra)
  - [DEFCON-23-Phil-Polstra-Extras.rar](https://media.defcon.org/DEF%20CON%2023/DEF%20CON%2023%20presentations/DEF%20CON%2023%20-%20Phil-Polstra-Extras.rar)
  - [UDeck](https://github.com/ppolstra/UDeck)

It worked for older images (Debian 8.7, 9.9, 10.13).  But, it doesn't work for newer images 
(Debian 11.7, 12.12, 13.1, Kernel 5.x, 6.x), because
  - most USB Gadget drivers are builtin, and
  - original scripts were written in Python2 which is no longer available in repository.

My work here solves these problems for newer kernels (6.17.8 is the latest confirmed)
and newer BBB images.


### Compiling kernel

It's similiar to compiling a kernel on PC, except you also need to install **.dtb**.
You can compile on BBB (slooow) or cross-compile on PC (faster, recommended).
It would go like
```
sudo apt install libssl-dev gcc-arm-linux-gnueabihf

export KBUILD_OUTPUT=5.10.168-kb
export LOCALVERSION=-kb
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make kernelversion
sed -f config.sed < ../config-5.10.168-ti-r83 > $KBUILD_OUTPUT/.config
make oldconfig
make kernelrelease

make  all
make  zinstall         INSTALL_PATH=boot_install
make  dtbs_install     INSTALL_PATH=boot_install
make  modules_install  INSTALL_MOD_PATH=modules_install
make  headers_install  INSTALL_HDR_PATH=headers_install
```
where `confi.sed` changes 2 kernel drivers (`usb_f_acm`, `usb_f_serial`) from builtin
to external modules.
```
/^CONFIG_USB_F_ACM=y/s/y/n/
/^CONFIG_USB_F_SERIAL=y/s/y/n/
/^CONFIG_USB_CONFIGFS_SERIAL=y/s/y/n/
/^CONFIG_USB_CONFIGFS_ACM=y/s/y/n/
```
You now have a new kernel and stuffs.  It's the same as the old, except for the 2 modules.
On Fedora, for some reason, `make zinstall` line doen't work, so you have to copy
3 files manually.
To collect them into your own directory, say `~/boot`,
```
cd $KBUILD_OUTPUT
  tar  -cJf  ~/boot/boot-$KBUILD_OUTPUT.tar.xz     boot_install
  tar  -cJf  ~/boot/modules-$KBUILD_OUTPUT.tar.xz  modules_install
  tar  -cJf  ~/boot/headers-$KBUILD_OUTPUT.tar.xz  headers_install
```


### Installing kernel

Copy the tarballs to BBB, and install them to
  - /boot
  - /boot/dtbs
  - /lib/modules

My BBB boots okay without *initrd.img*, but you may want to generate it for completeness.
```
export KBUILD_OUTPUT=5.10.168-kb

tar  -xJf  boot-$KBUILD_OUTPUT.tar.xz     --strip-components=1  -C  /boot         --no-same-owner  --no-same-permissions
tar  -xJf  modules-$KBUILD_OUTPUT.tar.xz  --strip-components=3  -C  /lib/modules  --no-same-owner  --no-same-permissions

depmod $KBUILD_OUTPUT
mkinitramfs -o initrd.img-$KBUILD_OUTPUT $KBUILD_OUTPUT
cp initrd.img-$KBUILD_OUTPUT /boot
```


### Configuring kernel modules

The 2 modules (`usb_f_acm`, `usb_f_serial`) must be blacklisted, 
so that they don't conflict with `usb_f_hid` which is what I want to access.
```
blacklist usb_f_acm
blacklist usb_f_serial
```


### Configuring /boot/uEnv.txt

BBB will look for `uname_r` files when it boots.
```
#uname_r=5.10.168-ti-r83
uname_r=5.10.168-kb
```


### Creating/Removing USB keyboard device

- `sudo ./create_keyboard.sh start` --- will create USB Gadget device `/dev/hidg0`.
- `sudo ./create_keyboard.sh stop` --- will remove and cleanup back to before.

### Sending strings

- `sudo ./send_line.sh arg...` --- will send the string arguments, separated by
  a space and terminated by newline.  It's as though you typed the line on a real keyboard.
