all:
	true

update:
	curl -s https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=python-raspberry-gpio > PKGBUILD
