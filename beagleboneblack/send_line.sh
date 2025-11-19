#!/bin/bash
#
# William Park <opengeometry@yahoo.ca>
# 2025
#
# Usage:  $0 string...
#
# It sends out strings to USB host.  Strings are separated with SP, and the
# line ends with LF.
#

. $(dirname "$0")/send_functions.sh

while [ $# -gt 0 ]; do
    sendString "$1"
    shift
    if [ $# -gt 0 ]; then
	sendSpace
    else
	sendEnter
    fi
done

