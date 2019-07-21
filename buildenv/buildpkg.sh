#!/bin/bash
set -x
set -e

pkg="$1"
repo="$2"
force="$3"
norepo="$4"

if [ ! -d "/packages/$pkg" ]; then
	echo "Required existent package"
	exit 1
fi

find /build -mindepth 1 -delete
cp -r "/packages/$pkg"/* /build
cd /build

. PKGBUILD

[ -z "$epoch" ] || epoch_prefix="$epoch:"
new_version="$epoch_prefix$pkgver-$pkgrel"
old_version=$(cat "/repo/latest/$pkg" 2>/dev/null || true)

if [ "$new_version" != "$old_version" -o -n "$force" ]; then
	if [ -f "/repo/$repo.db.tar.gz" ]; then
		echo -e "[$repo]\nServer = file:///repo\nSigLevel = Required DatabaseOptional" >> /etc/pacman.conf
	fi

	if [ ${#depends[@]} -ne 0 -o ${#makedepends[@]} -ne 0 ]; then
		pacman --noconfirm -Syy
		pacman --needed --noconfirm -S ${depends[@]} ${makedepends[@]}
	fi

	sudo -u alarm makepkg

	if [ -z "$norepo" ]; then
		sudo -u alarm bash -c "ls \"$pkg\"-*.pkg.tar.xz > done"
		sudo -u alarm cp "$pkg"-*.pkg.tar.xz /repo
		sudo -u alarm bash -c "echo \"$new_version\" > \"/repo/latest/$pkg\""
	fi
fi
