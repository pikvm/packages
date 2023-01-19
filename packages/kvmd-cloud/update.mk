all:
	true

update:
	curl -s https://raw.githubusercontent.com/pikvm/kvmd-cloud/master/PKGBUILD > PKGBUILD
	curl -s https://raw.githubusercontent.com/pikvm/kvmd-cloud/master/pkg.install > pkg.install
