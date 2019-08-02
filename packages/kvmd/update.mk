all:
	true

update:
	curl -s https://raw.githubusercontent.com/pi-kvm/kvmd/master/PKGBUILD > PKGBUILD
	curl -s https://raw.githubusercontent.com/pi-kvm/kvmd/master/kvmd.install > kvmd.install
