#!/bin/bash
#
# William Park <opengeometry@yahoo.ca>
# 2018-2025
#
# Usage:
# -----
#	sudo $0 list
#	sudo $0 stopall
#	sudo $0 start [keyboard, mouse, screen]
#	sudo $0 stop
#	sudo $0 clean
#
# This script creates USB Gadget devices on BeagleBone Black (BBB) board,
#
#	/dev/hidg0 -- keyboard
#	/dev/hidg1 -- mouse
#	/dev/hidg2 -- screen -- absolute mouse, a basic one-finger touchscreen.
#
# so that it can act as USB keyboard, mouse, and screen.
#
# Reference:
# ----------
# 	- https://docs.kernel.org/usb/gadget_configfs.html
# 	- https://docs.kernel.org/filesystems/configfs.html
# 	- https://github.com/qlyoung/keyboard-gadget
#	- https://github.com/ppolstra/UDeck
#
# Original work:
# --------------
# Original keyboard scripts (create-hid.sh, udeckHid.py) for BBB was written
# by Phil Polstra:
#	- media.defcon.org/DEF CON 23/DEF CON 23 presentations/DEFCON-23-Phil-Polstra-Extras.rar
#	- github.com/ppolstra/UDeck/
# 
# - It worked for older images (Debian 8.7, 9.9, 10.13), but doesn't work for
#   newer images (Debian 11.7, 12.12, 13.1, Kernel 5.x, 6.x).  
#
# - Original python script was written in Python2 which is no longer available
#   in repository.
#

KB_DIR=/sys/kernel/config/usb_gadget/kb
ACTION=$1	# start, stop
TARGETS=${*:2}	# keyboard, mouse, screen


Usage()
{
    cat <<EOF
Usage:
    sudo $0 list
    sudo $0 stopall
    sudo $0 start [keyboard, mouse, screen]
    sudo $0 stop
    sudo $0 clean
EOF
}


mkdir_cd()
{
    mkdir $1 && cd $1
}


# https://www.usb.org/sites/default/files/documents/hid1_11.pdf
#   Firmware Specification 6/27/01
#   Version 1.11
#   E.6 Report Descriptor (Keyboard), p69
#
# Use this.
#
cat_report_descriptor_keyboard()
{
    xxd -r -p <<EOF
	05 01 09 06 a1 01 05 07  19 e0 29 e7 15 00 25 01
	75 01 95 08 81 02 95 01  75 08 81 01 95 05 75 01
	05 08 19 01 29 05 91 02  95 01 75 03 91 01 95 06
	75 08 15 00 25 65 05 07  19 00 29 65 81 00 c0
EOF

}


# https://docs.kernel.org/usb/gadget-testing.html
# https://docs.kernel.org/usb/gadget_hid.html
#
# Two differences:
#	Input (constant)    #81 01 -> 03
#	Output (constant)   #91 01 -> 03
# 
cat_report_descriptor_keyboard3()
{
    xxd -r -p <<EOF
	05 01 09 06 a1 01 05 07  19 e0 29 e7 15 00 25 01
	75 01 95 08 81 02 95 01  75 08 81 03 95 05 75 01
	05 08 19 01 29 05 91 02  95 01 75 03 91 03 95 06
	75 08 15 00 25 65 05 07  19 00 29 65 81 00 c0
EOF
}


# https://www.usb.org/sites/default/files/documents/hid1_11.pdf
#   Firmware Specification 6/27/01
#   Version 1.11
#   E.10 Report Descriptor (Mouse), p71
#
# Byte 1: Button
# Byte 2: X (-127 to 127) -- relative motion
# Byte 3: Y (-127 to 127) -- relative motion
#
# Eg.
#	printf '%b' '\x01' '\x7f' '\x7f' > /dev/hidg1	# button 1, pressed/moved
#	printf '%b' '\x00' '\x00' '\x00' > /dev/hidg1	# button released
#
# Use this.
#
cat_report_descriptor_mouse()
{
    xxd -r -p <<EOF
	05 01 09 02 a1 01 09 01 a1 00 05 09 19 01 29 03
	15 00 25 01 95 03 75 01 81 02 95 01 75 05 81 01
	05 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 06
	c0 c0
EOF
}


# https://eunomia.dev/tutorials/49-hid/
# 
# Relative motion mouse.
#
# Byte 1: Button states
#	bit 0: Left button
#	bit 1: Right button
#	bit 2: Middle button
# Byte 2: X movement (signed 8-bit, -127 to +127)
# Byte 3: Y movement (signed 8-bit, -127 to +127)
#
# Eg.
#	printf '%b' '\x01' '\x7f' '\x7f' > /dev/hidg1	# button 1, pressed/moved
#	printf '%b' '\x00' '\x00' '\x00' > /dev/hidg1	# button released
#
cat_report_descriptor_mouse3()
{
    xxd -r -p <<EOF
	05 01 09 02 a1 01 09 01 a1 00 05 09 19 01 29 03
	15 00 25 01 95 03 75 01 81 02 95 01 75 05 81 03
	05 01 09 30 09 31 15 81 25 7f 75 08 95 02 81 06
	c0 c0
EOF
}


# Google AI:
#	- subclass = 1		-- Boot Interface subclass
#	- protocol = 2		-- Mouse protocol
#	- report_length = 8	-- 8 bytes
#
# Byte 1: Buttons
# Byte 2,3: X (1 to 32767=0x7fff, scaled) -- #26 xL xH
# Byte 4,5: Y (1 to 32767=0x7fff, scaled) -- #46 yL yH
# 
# - range is scaled, so the center of screen is (0x4000,0x4000).
#
# - to move to the centre,
#	printf '%b' '\x00' '\x00' '\x40' '\x00' '\x40'
#
# - to click button 1, press and release
#	printf '%b' '\x01' '\x00' '\x00' '\x00' '\x00' > /dev/hidg2
#	printf '%b' '\x00' '\x00' '\x00' '\x00' '\x00' > /dev/hidg2
#
cat_report_descriptor_mouse_screen()
{
    xxd -r -p <<EOF
	05 01 09 02 a1 01 09 01 a1 00 05 09 19 01 29 03
	15 00 25 01 95 03 75 01 81 02 95 01 75 05 81 01
	05 01 09 30 09 31 15 00 26 ff 7f 35 00 46 ff 7f
	75 10 95 02 81 02 c0 c0
EOF
}


do_start()
{
    modprobe usb_f_hid

    if [[ ! -d $KB_DIR ]] && mkdir_cd $KB_DIR; then
	echo 0x1d6b > idVendor	    # Linux Foundation
	echo 0x0104 > idProduct	    # Multifunction Composite Gadget
	echo 0x0100 > bcdDevice	    # v1.0.0
	echo 0x0110 > bcdUSB	    # 0x0110=USB1.1, 0x0200=USB2

	if mkdir_cd $KB_DIR/strings/0x409; then	    # 0x409 -- English
	    echo BeagleBoard.org Foundation > manufacturer
	    echo USB Gadget Keyboard/Mouse  > product
	    echo 2025-11		    > serialnumber
	fi

	for i in $TARGETS; do
	    case $i in
		keyboard)
		    if mkdir_cd $KB_DIR/functions/hid.usb0; then
			echo 1 > subclass	# Boot Interface subclass
			echo 1 > protocol	# Keyboard protocol
			echo 8 > report_length	# 8 bytes
			cat_report_descriptor_keyboard > report_desc 
		    fi
		    ;;

		mouse)
		    if mkdir_cd $KB_DIR/functions/hid.usb1; then
			echo 1 > subclass	# Boot Interface subclass
			echo 2 > protocol	# Mouse protocol
			echo 3 > report_length	# 3 bytes
			cat_report_descriptor_mouse > report_desc 
		    fi
		    ;;

		screen)
		    if mkdir_cd $KB_DIR/functions/hid.usb2; then
			echo 1 > subclass	# Boot Interface subclass
			echo 2 > protocol	# Mouse protocol
			echo 5 > report_length	# AI says 8 bytes, should be 5
			cat_report_descriptor_mouse_screen > report_desc 
		    fi
		    ;;
		*)
		    echo "$i: unknown target, must be {keyboard, mouse, screen}."
		    ;;
	    esac
	done

	if mkdir_cd $KB_DIR/configs/c.1; then
	    echo 500 > MaxPower
	    ln -sf $KB_DIR/functions/hid.usb? ./

	    if mkdir_cd $KB_DIR/configs/c.1/strings/0x409; then	# 0x409 -- English
		echo Sample Configuration > configuration
	    fi
	fi
    fi

    # Activate using devices from /sys/class/udc/.
    if cd $KB_DIR; then
	echo musb-hdrc.0 > UDC		# activate
	chmod a+=rw /dev/hidg?
    fi
}


do_stop()
{
    if cd $KB_DIR; then
	echo > UDC
    fi
}


# Undo what has been done, in reverse order.
# 
# find /sys/kernel/config/usb_gadget/kb/ -type l -delete
# find /sys/kernel/config/usb_gadget/kb/ -type d \( -name hid.usb? -o -name 0x409 -o -name c.1 \) -delete
#
do_clean()
{
    if cd $KB_DIR; then
	rm    $KB_DIR/configs/c.1/hid.usb?
	rmdir $KB_DIR/configs/c.1/strings/0x409
	rmdir $KB_DIR/configs/c.1
	rmdir $KB_DIR/functions/hid.usb?
	rmdir $KB_DIR/strings/0x409
	rmdir $KB_DIR
    fi
}


do_list()
{
    ls /sys/kernel/config/usb_gadget/
}


do_stopall()
{
    for i in /sys/kernel/config/usb_gadget/*; do
	echo > $i/UDC
    done
}


case $ACTION in
    list)     do_list     ;;
    stopall)  do_stopall  ;;
    start)    do_start    ;;
    stop)     do_stop     ;;
    clean)    do_clean    ;;
    *)        Usage       ;;
esac

