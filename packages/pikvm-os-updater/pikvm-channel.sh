#!/bin/bash
set -eE

export LC_ALL=C
export LANG=C

if [ `whoami` != root ]; then
	echo "============================"
	echo "Please run it under the root"
	echo "============================"
	exit 1
fi

if [ -f /usr/lib/kvmd/platform ]; then
	source /usr/lib/kvmd/platform
elif [ -f /usr/share/kvmd/platform ]; then
	source /usr/share/kvmd/platform
else
	echo "============================="
	echo "Can't find KVMD platform file"
	echo "============================="
	exit 1
fi

_url="https://files.pikvm.org/repos"
case "$1" in
	stable) _url="$_url/arch/$PIKVM_BOARD";;
	testing) _url="$_url/arch-testing/$PIKVM_BOARD";;
	*) echo "Usage: pikvm-channel stable|testing"; exit 1;;
esac

if [ `uname -m` = aarch64 ]; then
	_url="$_url-aarch64"
else
	_url="$_url-arm"
fi

cat << EOF > /etc/pacman.d/pikvm
Server = $_url
SigLevel = Required DatabaseOptional
EOF

sed -i '/^\[pikvm\]$/,/^\[/ {
	/^\[pikvm\]$/!{
		/^\[/!d
	}
	/^\[pikvm\]$/a Include = /etc/pacman.d/pikvm
}' /etc/pacman.conf
