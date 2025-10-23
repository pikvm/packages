all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/kvmd/master/PKGBUILD > PKGBUILD
	curl -s https://raw.githubusercontent.com/pikvm/kvmd/master/kvmd.install > kvmd.install
	curl -s https://raw.githubusercontent.com/pikvm/kvmd/master/platform.install > platform.install
