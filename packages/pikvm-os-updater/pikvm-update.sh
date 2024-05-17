#!/bin/bash
set -eE

export LC_ALL=C
export LANG=C

if [ `whoami` != root ]; then
	set +x
	echo "============================"
	echo "Please run it under the root"
	echo "============================"
	set -x
	exit 1
fi

_opt_no_self_update=""
_opt_no_reboot=""
while test "$#" != 0; do
	case "$1" in
		--no-self-update) _opt_no_self_update=1;;
		--no-reboot) _opt_no_reboot=1;;
		*) echo "Usage: pikvm-update [--no-reboot]"; exit 1;;
	esac
	shift
done

set -x

function show_rw_msg() {
	set +x
	echo "=============================================================="
	echo "Please note that the filesystem now remain in Read-Write mode."
	echo "       A reboot is necessary to make it Read-Only again."
	echo "The reboot can be performed later using the 'reboot' command."
	echo "=============================================================="
	set -x
}
function on_error() {
	set +x
	echo "=============================================================="
	echo "      An unexpected error occurred during the update."
	echo "=============================================================="
	echo
	show_rw_msg
	set -x
}
trap on_error ERR

_yes="--noconfirm --ask=4 --overwrite \\*"

rw
pacman -Syy

if [ `pacman -S -u --print-format %n | grep -v pikvm-os-updater | wc -l` -eq 0 ]; then
	set +x
	echo "================================"
	echo "Your PiKVM is already up-to-date"
	echo "================================"
	set -x
	ro
	exit 0
fi

rm -f /var/cache/pacman/pkg/*

if [ -z "$_opt_no_self_update" ]; then
	if [ `pacman -S --needed --print-format %n pikvm-os-updater | wc -l` -ne 0 ]; then
		pacman $_yes -S pikvm-os-updater
		_opts=--no-self-update
		if [ -n "$_opt_no_reboot" ]; then
			_opts="$_opts --no-reboot"
			trap - ERR
		fi
		pikvm-update $_opts
		exit $?
	fi
fi

if ! grep -q "^C.UTF-8 UTF-8" /etc/locale.gen; then
	# bsdtar: bsdtar: Failed to set default localeFailed to set default locale
	echo "C.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen || true
fi

for _pkg in rpi-eeprom rpi4-eeprom; do
	if pacman -Q $_pkg >/dev/null 2>&1; then
		pacman --noconfirm --ask=4 -R $_pkg
	fi
done

#rm -f \
#       /usr/bin/vcgencmd \
#       /usr/lib/firmware/brcm/brcmfmac4356-sdio.AP6356S.txt \
#       /usr/lib/firmware/updates/brcm/brcmfmac43430-sdio.txt

if (pacman -Qi python-ajsonrpc | grep Depends | grep -q 'python<3\.12'); then
	rm -f /var/cache/pacman/pkg/python-ajsonrpc-*
	pacman $_yes -S python-ajsonrpc
fi

if ! pacman -Q raspberrypi-utils libgpiod >/dev/null 2>&1; then
	pacman $_yes --needed -S \
		raspberrypi-utils \
		ustreamer \
		pikvm-os-raspberrypi \
		libgpiod \
		kvmd-fan \
		kvmd \
		`pacman -Q | grep kvmd-platform | awk '{print $1}'` \
		python-luma-core \
		python-luma-oled \
		python-pyftdi \
		python-pyghmi \
		python-pyrad \
		python-pyserial-asyncio \
		python-raspberry-gpio \
		python-smbus2 \
		python-spidev
fi

pacman $_yes -Su

if systemctl is-enabled -q tailscaled; then
	systemctl restart tailscaled
	tailscale up
fi

if ! kvmd -m >/dev/null 2>&1; then
	set +x
	echo "=================================================="
	echo "     During the update, something went wrong"
	echo " and the KVMD configuration was no longer valid."
	echo "             _____________________"
	echo "             !!! DO NOT REBOOT !!!"
	echo "             ---------------------"
	echo
	echo "  Please do following:"
    echo "  * Run 'kvmd -m' command to check the config."
	echo "  * Fix the error."
	echo "  * After that, run 'kvmd -m' again."
	echo "  * If you see a large and beautiful configuration"
    echo "    dump, you can run the 'reboot' command."
	echo "  * If you are unable to fix the error,"
	echo "  * please contact our online support chat:"
	echo "       __________________________________"
	echo "       >>> https://discord.gg/bpmXfz5 <<<"
	echo "       ----------------------------------"
	echo "=================================================="
	set -x
	exit 1
fi

if [ -z "$_opt_no_reboot" ]; then
	set +x
	echo "=============================================================="
	echo "      Reboot required. We will make it after 30 seconds."
	echo "            Press Ctrl+C if you don't want this."
	echo "=============================================================="
	echo
	show_rw_msg
	set -x
	sleep 30
	reboot
else
	trap - ERR
	set +x
	echo "=============================================================="
	echo "        Reboot required. Please perfrorm it manually."
	echo "=============================================================="
	echo
	show_rw_msg
	set -x
	exit 100
fi
