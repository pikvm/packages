all:
	true

update:
	curl -s https://raw.githubusercontent.com/pi-kvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(raspberrypi-firmware wiringpi /g" \
		> PKGBUILD
