all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(raspberrypi-firmware /g" \
		> PKGBUILD
