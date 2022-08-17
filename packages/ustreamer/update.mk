all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(raspberrypi-firmware janus-gateway-pikvm alsa-lib opus speexdsp /g" \
			| sed -e "s/(janus-gateway /(janus-gateway-pikvm /g" \
		> PKGBUILD
