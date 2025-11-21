# BeagleBone Black (BBB) related stuffs

  - [make_keyboard.sh](make_keyboard.sh) --- creates USB Gadget devices
  - [send_functions.sh](send_functions.sh) --- collection of shell functions
  - [send_line.sh](send_line.sh) --- sends string arguments, separated by a space and terminated by newline.


----
## 1. BBB as scriptable keyboard, mouse, and touch screen
----
Using USB Gadget driver, you can make BBB into a scriptable keyboard, mouse, and touchscreen
device.  This means, for an example, you can send out "key presses" from USB device port
(mini-USB).  From USB host side (usually PC), it appears just like another keyboard.

Original work on keyboard emulation for BBB was done by Phil Polstra (@ppolstra)
  - [DEFCON-23-Phil-Polstra-Extras.rar](https://media.defcon.org/DEF%20CON%2023/DEF%20CON%2023%20presentations/DEF%20CON%2023%20-%20Phil-Polstra-Extras.rar)
  - [UDeck](https://github.com/ppolstra/UDeck)

It works for older images (Debian 8.7, 9.9, 10.13), but doesn't work for newer images 
(Debian 11.7, 12.12, 13.1, Kernel 5.x, 6.x).  Also, original scripts were written in Python2
which is no longer available in repository for BBB.

My work here 
  - solves these problems for newer BBB images with newer kernels, and
  - includes the emulation of keyboard, mouse, and touchscreen (absolute mouse).


### Creating/Removing USB Gadget devices

1. `sudo ./make_keyboard.sh start [keyboary mouse screen]` --- will create 3 USB Gadget devices
    - `/dev/hidg0` --- regular keyboard
    - `/dev/hidg1` --- regular mouse, with relative motion
    - `/dev/hidg2` --- screen or absolute mouse, a basic one-finger touchscreen

   You can specify 0, 1, 2, or all 3 devices, and it will start creating from `/dev/hidg0` and up.
   If you specify 0 device, then it will simply activate (ie. turn on) devices previously deactivated with
   `stop` action.
  
3. `sudo ./make_keyboard.sh stop` --- deactivates (ie. turn off) devices created with previously `start` action.

4. `sudo ./make_keyboard.sh clean` --- removes and cleans up all devices previously created with
   `start` action.  You will have to recreate them, later.

5. `sudo ./make_keyboard.sh stopall` --- deactivates all USB Gadget devices found in the system.

6. `sudo ./make_keyboard.sh list` --- lists all USB Gadget devices found in the system.


### Sending text strings as "keyboard"

```
./send_line.sh {A..Z} {a..z}
```
will send the alphabets, separated by a space and terminated by newline,
to `/dev/hidg0`.  It's as though you typed the line on a real keyboard.  Internally,
it will load shell functions from `send_functions.sh` which is rewrite of
[udeckHid.py](https://github.com/ppolstra/UDeck/blob/master/udeckHid.py) in Shell.

`send_line.sh` is just frontend.  You probably want to use functions in `send_functions.sh`
directly, eg.
```
. send_functions.sh
sendWindowKey d
```
which are the same as pressing Windows+D (show desktop) key.


### Sending mouse click and movement as "mouse"

```
printf %b '\x01\x00\x00' > /dev/hidg1
printf %b '\x00\x00\x00' > /dev/hidg1
printf %b '\x00\x7f\x00' > /dev/hidg1 
```
will simulate mouse button1 clicked (press and release), and then moving 127 to right.


### Moving mouse as "touch screen"

```
printf %b '\x00\x00\x40\x00\x40' > /dev/hidg2
```
will move mouse to the centre of screen, no matter where it was.  The X,Y ranges are 
scaled from 1 to 32767 or 0x7fff.  So, (1, 1) is top left corner, (0x7fff, 0x7fff)
is bottom right corner, and the screen centre is exactly (0x4000, 0x4000).

This is very useful for "automated QA testing".

----
## 2. Compiling a new kernel
----

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
make oldconfig
make kernelrelease

make  all
make  zinstall         INSTALL_PATH=boot_install
make  dtbs_install     INSTALL_PATH=boot_install
make  modules_install  INSTALL_MOD_PATH=modules_install
make  headers_install  INSTALL_HDR_PATH=headers_install
```
You now have a new kernel and stuffs.
On Fedora, for some reason, `make zinstall` line doen't work, so you have to do that step manually.
Finally, make tarballs of the 3 installed locations.
```
cd $KBUILD_OUTPUT
    tar  -cJf  boot-$KBUILD_OUTPUT.tar.xz     boot_install
    tar  -cJf  modules-$KBUILD_OUTPUT.tar.xz  modules_install
    tar  -cJf  headers-$KBUILD_OUTPUT.tar.xz  headers_install
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


### Configuring /boot/uEnv.txt

```
#uname_r=5.10.168-ti-r83
uname_r=5.10.168-kb
```
When BBB boots, it will look for relevant files in `/boot`, `/lib/dtbs`, and `/lib/modules`.
