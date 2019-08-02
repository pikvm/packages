BOARD ?= rpi3


# =====
_REPO_NAME = pikvm
_REPO_KEY = 912C773ABBD1B584
_REPO_DEST = root@pikvm.org:/var/www/

_MAIN_REPO_URL = http://mirror.yandex.ru/archlinux-arm

_BUILDENV_DIR = ./.pi-builder/$(BOARD)
_BUILD_DIR = ./.build/$(BOARD)
_REPO_DIR = ./repos/$(BOARD)

_UPDATABLE_PACKAGES := $(sort $(subst /update.mk,,$(subst packages/,,$(wildcard packages/*/update.mk))))
_KNOWN_BOARDS := $(sort $(filter rpi%,$(subst order., ,$(wildcard packages/order.*))))


# =====
_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
_SAY := $(_ROOT)/buildenv/say

_NULL :=
_SPACE := $(_NULL) $(_NULL)

define join_spaced
$(subst $(_SPACE),|,$1)
endef

define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef


# =====
all:
	@ echo "Available commands:"
	@ echo "    make buildenv BOARD=<$(call join_spaced,$(_KNOWN_BOARDS))> NC=<1|0>"
	@ echo "    make shell BOARD=<$(call join_spaced,$(_KNOWN_BOARDS))>"
	@ echo
	@ echo "    make update"
	@ for target in $(_UPDATABLE_PACKAGES); do echo "    make update-$$target"; done
	@ echo
	@ echo "    make packages"
	@ for board in $(_KNOWN_BOARDS); do echo "    make packages-$$board"; done


upload:
	rsync -rl --progress repos $(_REPO_DEST)


define make_update_package_target
update-$1:
	make -C packages/$1 -f update.mk update
endef
$(foreach pkg,$(_UPDATABLE_PACKAGES),$(eval $(call make_update_package_target,$(pkg))))
update: $(addprefix update-,$(_UPDATABLE_PACKAGES))


define make_packages_board_target
packages-$1:
	make buildenv NC=$$(NC) BOARD=$1
	cat packages/order.$1 | xargs -n1 -L1 bash -c 'make build BOARD=$1 PKG=$$$$0 || exit 255'
endef
$(foreach board,$(_KNOWN_BOARDS),$(eval $(call make_packages_board_target,$(board))))
packages: $(addprefix packages-,$(_KNOWN_BOARDS))


build:
	@ $(_SAY) "===== Ensuring package $(PKG) for $(BOARD) ====="
	rm -rf $(_BUILD_DIR)
	make _run BOARD=$(BOARD) CMD="/tools/buildpkg $(PKG) $(_REPO_NAME) '$(call optbool,$(FORCE))'"
	test ! -s $(_BUILD_DIR)/done || ( \
		pushd $(_BUILD_DIR) \
		&& cat done | xargs -n1 -L1 bash -c 'gpg --local-user $(_REPO_KEY) --detach-sign --use-agent $$0 || exit 255' \
		&& popd \
		&& ( test -n '$(call optbool,$(NOREPO))' || ( \
			$(_SAY) "===== Placing package $(PKG) into repo =====" \
			&& cp $(_BUILD_DIR)/*.pkg.tar.xz $(_BUILD_DIR)/*.pkg.tar.xz.sig $(_REPO_DIR) \
			&& make _run BOARD=$(BOARD) CMD="bash -c 'cd /repo && repo-add --new $(_REPO_NAME).db.tar.gz *.pkg.tar.xz'" \
			&& cp $(_BUILD_DIR)/version $(_REPO_DIR)/latest/$(PKG) \
		)) \
	)
	@ $(_SAY) "===== Complete package $(PKG) for $(BOARD) ====="


shell:
	make _run BOARD=$(BOARD) CMD=/bin/bash OPTS=-i


buildenv: $(_BUILDENV_DIR)
	make -C $(_BUILDENV_DIR) binfmt
	@ $(_SAY) "===== Ensuring $(BOARD) buildenv ====="
	rm -rf $(_BUILDENV_DIR)/stages/buildenv
	cp -a buildenv $(_BUILDENV_DIR)/stages/buildenv
	make -C $(_BUILDENV_DIR) os \
		NC=$(NC) \
		PASS_ENSURE_TOOLBOX=1 \
		PASS_ENSURE_BINFMT=1 \
		BUILD_OPTS="--build-arg REPO_KEY=$(_REPO_KEY)" \
		PROJECT=pikvm-buildenv \
		BOARD=$(BOARD) \
		STAGES="__init__ buildenv" \
		HOSTNAME=buildenv \
		REPO_URL=$(_MAIN_REPO_URL)
	@ $(_SAY) "===== Buildenv $(BOARD) is ready ====="


# =====
_run:
	mkdir -p $(_BUILD_DIR) $(_REPO_DIR)/{,latest}
	make -C $(_BUILDENV_DIR) run \
		PASS_ENSURE_TOOLBOX=1 \
		PASS_ENSURE_BINFMT=1 \
		BOARD=$(BOARD) \
		RUN_CMD="$(CMD)" \
		RUN_OPTS=" \
			--volume `pwd`/packages:/packages:ro \
			--volume `pwd`/$(_REPO_DIR):/repo:rw \
			--volume `pwd`/$(_BUILD_DIR):/build:rw \
			$(OPTS) \
		"


$(_BUILDENV_DIR):
	git clone --depth=1 https://github.com/pi-kvm/pi-builder $(_BUILDENV_DIR)


.PHONY: buildenv packages repos
