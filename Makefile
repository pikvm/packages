BOARD ?= rpi3


# =====
_REPO_NAME = pikvm
_REPO_KEY = 912C773ABBD1B584
_REPO_DEST = root@pikvm.org:/var/www/

_MAIN_REPO_URL = http://mirror.yandex.ru/archlinux-arm

_BUILDER_DIR = ./.pi-builder-$(BOARD)

_SAY = $(_BUILDER_DIR)/tools/say


# =====
all:
	true


upload:
	rsync -rl --progress repos $(_REPO_DEST)


update:
	# python-raspberry-gpio
	curl https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=python-raspberry-gpio \
		> packages/python-raspberry-gpio/PKGBUILD
	# ustreamer
	curl https://raw.githubusercontent.com/pi-kvm/ustreamer/master/pkg/arch/PKGBUILD \
			| sed -e "s/^depends=(/depends=(raspberrypi-firmware wiringpi /g" \
		> packages/ustreamer/PKGBUILD
	# kvmd
	curl https://raw.githubusercontent.com/pi-kvm/kvmd/master/PKGBUILD \
		> packages/kvmd/PKGBUILD
	curl https://raw.githubusercontent.com/pi-kvm/kvmd/master/kvmd.install \
		> packages/kvmd/kvmd.install


repos:
	make packages BOARD=rpi
	make packages BOARD=rpi2
	make packages BOARD=rpi3


packages:
	make buildenv BOARD=$(BOARD)
	cat packages/order.$(BOARD) | xargs -n1 -L1 bash -c 'make build BOARD=$(BOARD) PKG=$$0 || exit 255'


build:
	@ $(_SAY) "===== Ensuring package $(PKG) for $(BOARD) ====="
	make _run CMD="/buildpkg.sh $(PKG) $(_REPO_NAME) '$(FORCE)'"
	test ! -s .build/done || ( \
		pushd .build \
		&& cat done | xargs -n1 -L1 bash -c 'gpg --local-user $(_REPO_KEY) --detach-sign --use-agent $$0 || exit 255' \
		&& popd \
		&& ( test -n "$(NOREPO)" || ( \
			cp .build/*.pkg.tar.xz .build/*.pkg.tar.xz.sig repos/$(BOARD) \
			&& make _run CMD="bash -c 'cd /repo && repo-add --new $(_REPO_NAME).db.tar.gz *.pkg.tar.xz'" \
			&& cp .build/version repos/$(BOARD)/latest/$(PKG) \
		)) \
	)
	rm -rf .build
	@ $(_SAY) "===== Complete package $(PKG) for $(BOARD) ====="


shell:
	make _run CMD=/bin/bash OPTS=-i


buildenv: $(_BUILDER_DIR)
	@ $(_SAY) "===== Ensuring $(BOARD) buildenv ====="
	rm -rf $(_BUILDER_DIR)/stages/buildenv
	cp -a buildenv $(_BUILDER_DIR)/stages/buildenv
	make -C $(_BUILDER_DIR) os \
		BUILD_OPTS="--build-arg REPO_KEY=$(_REPO_KEY)" \
		PROJECT=pikvm-buildenv \
		BOARD=$(BOARD) \
		STAGES="__init__ buildenv" \
		HOSTNAME=buildenv \
		REPO_URL=$(_MAIN_REPO_URL)
	@ $(_SAY) "===== Buildenv $(BOARD) is ready ====="


_run:
	mkdir -p .build repos/$(BOARD)/{,latest}
	make -C $(_BUILDER_DIR) run \
		BOARD=$(BOARD) \
		RUN_CMD="$(CMD)" \
		RUN_OPTS=" \
			--volume `pwd`/packages:/packages:ro \
			--volume `pwd`/repos/$(BOARD):/repo:rw \
			--volume `pwd`/.build:/build:rw \
			$(OPTS) \
		"


$(_BUILDER_DIR):
	git clone --depth=1 https://github.com/pi-kvm/pi-builder $(_BUILDER_DIR)


.PHONY: buildenv packages repos
