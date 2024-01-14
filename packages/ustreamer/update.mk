all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(janus-gateway-pikvm alsa-lib opus speexdsp /g" \
			| sed -e "s/(janus-gateway /(janus-gateway-pikvm /g" \
			| sed -e 's/\<libgpiod\>/"libgpiod1>=2.0"/g' \
			| sed -e "s/pkgrel=1/pkgrel=2/g" \
		> PKGBUILD
