#!/bin/sh
#
# William Park <opengeometry@yahoo.ca>
# 2018-2025
#
# The original script (udeckHid.py) was written by Phil Polstra.  
#     - media.defcon.org/DEF CON 23/DEF CON 23 presentations/DEFCON-23-Phil-Polstra-Extras.rar
#     - github.com/ppolstra/UDeck/
#
# Rewritten for newer BBB images, because Python2 is no longer available.
# 

LeftCtrl=1
LeftShift=2
LeftAlt=4
LeftGui=8
RightCtrl=16
RightShift=32
RightAlt=64
RightGui=128

# ascii   modifier.keycode
#
declare -A AsciiToKey=(
    BS   0.42
    HT   0.43
    $'\t'   0.43
    LF   0.40
    $'\n'   0.40
    ESC  0.41
    SP   0.44
    ' '  0.44
    "'"  0.52
    '!'  2.30
    '"'  2.52
    '#'  2.32
    '$'  2.33
    '%'  2.34
    '&'  2.36
    '('  2.38
    ')'  2.39
    '*'  2.37
    '+'  2.46
    ','  0.54
    '-'  0.45
    '.'  0.55
    '/'  0.56
    '0'  0.39
    '1'  0.30
    '2'  0.31
    '3'  0.32
    '4'  0.33
    '5'  0.34
    '6'  0.35
    '7'  0.36
    '8'  0.37
    '9'  0.38
    ':'  2.51
    ';'  0.51
    '<'  2.54
    '='  0.46
    '>'  2.55
    '?'  2.56
    '@'  2.31
    'A'  2.4
    'B'  2.5
    'C'  2.6
    'D'  2.7
    'E'  2.8
    'F'  2.9
    'G'  2.10
    'H'  2.11
    'I'  2.12
    'J'  2.13
    'K'  2.14
    'L'  2.15
    'M'  2.16
    'N'  2.17
    'O'  2.18
    'P'  2.19
    'Q'  2.20
    'R'  2.21
    'S'  2.22
    'T'  2.23
    'U'  2.24
    'V'  2.25
    'W'  2.26
    'X'  2.27
    'Y'  2.28
    'Z'  2.29
    '['  0.47
    '\'  0.49
    ']'  0.48
    '^'  2.35
    '_'  2.45
    '`'  0.53
    'a'  0.4
    'b'  0.5
    'c'  0.6
    'd'  0.7
    'e'  0.8
    'f'  0.9
    'g'  0.10
    'h'  0.11
    'i'  0.12
    'j'  0.13
    'k'  0.14
    'l'  0.15
    'm'  0.16
    'n'  0.17
    'o'  0.18
    'p'  0.19
    'q'  0.20
    'r'  0.21
    's'  0.22
    't'  0.23
    'u'  0.24
    'v'  0.25
    'w'  0.26
    'x'  0.27
    'y'  0.28
    'z'  0.29
    '{'  2.47
    '|'  2.49
    '}'  2.48
    '~'  2.53
)


# Send out 8-bytes:
#    modifier	-- 1 byte
#    0x00	-- 1
#    keycode	-- 1
#    0x00	-- 1
#    0x00000000	-- 4
#	
sendKey()	# modifier keycode
{
    local -i modifier=$1 keycode=$2

    # Put the keycode at the end, to avoid problem with missing 'G' and 'g'.
    # Somehow, system sees 'G' and 'g' (keycode=0x0a) as '\n' and doesn't send
    # the entire 8 byte record.
    #
    local pressed=$(printf '\\x%02x' $((modifier%256)) 0 0 0  0 0 0 $((keycode%256)))
    local released=$(printf '\\x%02x' 0 0 0 0  0 0 0 0)

    printf '%b' "$pressed" "$released" > /dev/hidg0
}

sendModChar()	# modifier char
{
    local modifier=$1 char=$2
    local mod_key=${AsciiToKey[$char]}
    local mod=${mod_key%.*}
    local key=${mod_key#*.}
    local q_char

    if [[ -z $mod_key ]]; then
	q_char=$(printf '%q' "$char")
	echo "-- ${FUNCNAME}(): Unknown char={$q_char}"
    else
	sendKey $modifier $key
    fi
}

sendChar()	# char...
{
    local char mod_key mod key
    local q_char

    for char; do
	mod_key=${AsciiToKey[$char]}
	mod=${mod_key%.*}
	key=${mod_key#*.}

	if [[ -z $mod_key ]]; then
	    q_char=$(printf '%q' "$char")
	    echo "-- ${FUNCNAME}(): Unknown char={$q_char}"
	else
	    sendKey $mod $key
	fi
    done
}

sendString()	# string
{
    local str=$1
    local -i len i

    len=${#str}
    for ((i=0; i<len; i++)); do
	sendChar "${str:i:1}"
    done
}

sendLine()	# string (+ LF)
{
    sendStrings "$1"
    sendEnter
}

sendEnter()  {  sendChar  LF ;  }
sendEsc()    {  sendChar  ESC;  }
sendTab()    {  sendChar  HT ;  }
sendSpace()  {  sendChar  SP ;  }

sendCtrlKey()    {  sendModChar  1  "$1";  }
sendShiftKey()   {  sendModChar  2  "$1";  }
sendAltKey()     {  sendModChar  4  "$1";  }
sendWindowKey()  {  sendModChar  8  "$1";  }

sendFunc()	# number
{
    local -i num=$1

    if [[ num -lt 13 ]]; then
	sendKey 0 $((0x39 + num))
    elif [[ num -lt 25 ]]; then
	sendKey 0 $((0x5b + num))
    fi
}

sendCapsLock()     {  sendKey  0  0x39;  }
sendPrintScreen()  {  sendKey  0  0x46;  }
sendScrollLock()   {  sendKey  0  0x47;  }
sendPause()        {  sendKey  0  0x48;  }
sendInsert()       {  sendKey  0  0x49;  }
sendHome()         {  sendKey  0  0x4a;  }
sendPageUp()       {  sendKey  0  0x4b;  }
sendDelete()       {  sendKey  0  0x4c;  }
sendEnd()          {  sendKey  0  0x4d;  }
sendPageDown()     {  sendKey  0  0x4e;  }
sendRightArrow()   {  sendKey  0  0x4f;  }
sendLeftArrow()    {  sendKey  0  0x50;  }
sendDownArrow()    {  sendKey  0  0x51;  }
sendUpArrow()      {  sendKey  0  0x52;  }
sendNumLock()      {  sendKey  0  0x53;  }
sendApplication()  {  sendKey  0  0x65;  }
sendPower()        {  sendKey  0  0x66;  }
sendExecute()      {  sendKey  0  0x74;  }
sendHelp()         {  sendKey  0  0x75;  }
sendMenu()         {  sendKey  0  0x76;  }
sendMute()         {  sendKey  0  0x7f;  }
sendVolumeUp()     {  sendKey  0  0x80;  }
sendVolumeDown()   {  sendKey  0  0x81;  }

sendWindow()	   {  sendKey  8  0x00;  }	# Windows key only
