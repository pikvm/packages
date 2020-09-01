all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/kvmd/master/PKGBUILD > PKGBUILD
	curl -s https://raw.githubusercontent.com/pikvm/kvmd/master/kvmd.install > kvmd.install
