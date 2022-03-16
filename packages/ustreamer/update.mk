all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/m2m/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(raspberrypi-firmware janus-gateway-pikvm /g" \
		> PKGBUILD
