all:
	true

update:
	curl -s https://raw.githubusercontent.com/adamoutler/kvmd-certmgr-thirdparty/main/PKGBUILD > PKGBUILD
	curl -s https://raw.githubusercontent.com/adamoutler/kvmd-certmgr-thirdparty/main/kvmd-certmgr-thirdparty.install > kvmd-certmgr-thirdparty.install
