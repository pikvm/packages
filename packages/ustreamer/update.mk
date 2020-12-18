all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/master/pkg/arch/PKGBUILD > PKGBUILD
ifneq ($(BOARD),generic)
	sed -i -e "s/^depends=(/depends=(raspberrypi-firmware /g" PKGBUILD
endif
