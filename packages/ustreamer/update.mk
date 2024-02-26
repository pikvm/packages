all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e 's/^_options="/_options="WITH_V4P=1 /g' \
			| sed -e "s/^depends=(/depends=(libdrm janus-gateway-pikvm alsa-lib opus speexdsp /g" \
			| sed -e "s/(janus-gateway /(janus-gateway-pikvm /g" \
		> PKGBUILD
