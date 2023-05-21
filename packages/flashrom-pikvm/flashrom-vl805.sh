#!/bin/bash
set -e
case "$1" in
	default) target=default.bin;; # 138a1
	usb3) target=usb3.bin;; # hub
	*) echo "Usage: $0 default|usb3"; exit 1;;
esac
fw="/usr/lib/flashrom-pikvm/$target"
tmp="`mktemp`"

function cleanup() {
	rm -f "$tmp"
}
trap cleanup EXIT

dd if=/dev/zero bs=1024 count=1024 | tr "\000" "\377" >"$tmp"
dd if="$fw" of="$tmp" conv=notrunc
flashrom -p vl805 -w "$tmp"
