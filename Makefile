BOARD ?= rpi3


# =====
_REPO_NAME = pikvm
_REPO_KEY = 912C773ABBD1B584
_REPO_DEST = root@pikvm.org:/var/www/

_BUILDENV_IMAGE = pikvm/packages-buildenv-$(BOARD)
_BUILDENV_DIR = ./.pi-builder/$(BOARD)
_BUILD_DIR = ./.build/$(BOARD)
_REPO_DIR = ./repos/$(BOARD)

_UPDATABLE_PACKAGES := $(sort $(subst /update.mk,,$(subst packages/,,$(wildcard packages/*/update.mk))))
_KNOWN_BOARDS := $(sort $(filter rpi%,$(subst order., ,$(wildcard packages/order.*))))


# =====
_NULL :=
_SPACE := $(_NULL) $(_NULL)

define join_spaced
$(subst $(_SPACE),|,$1)
endef

define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef

define say
@ tput bold
@ tput setaf 2
@ echo "===== $1 ====="
@ tput sgr0
endef

define die
@ tput bold
@ tput setaf 1
@ echo "===== $1 ====="
@ tput sgr0
@ exit 1
endef


# =====
all:
	@ echo "Available commands:"
	@ echo "    make binfmt BOARD=<$(call join_spaced,$(_KNOWN_BOARDS))>"
	@ echo "    make buildenv BOARD=<$(call join_spaced,$(_KNOWN_BOARDS))> NC=<1|0>"
	@ echo "    make shell BOARD=<$(call join_spaced,$(_KNOWN_BOARDS))>"
	@ echo "    make push"
	@ echo "    make pull"
	@ echo
	@ echo "    make update"
	@ for target in $(_UPDATABLE_PACKAGES); do echo "    make update-$$target"; done
	@ echo
	@ echo "    make packages"
	@ for board in $(_KNOWN_BOARDS); do echo "    make packages-$$board"; done
	@ echo
	@ echo "    make upload"


upload:
	rsync -rl --progress --delete repos $(_REPO_DEST)


define make_update_package_target
update-$1:
	make -C packages/$1 -f update.mk update
endef
$(foreach pkg,$(_UPDATABLE_PACKAGES),$(eval $(call make_update_package_target,$(pkg))))
update: $(addprefix update-,$(_UPDATABLE_PACKAGES))


define make_packages_board_target
packages-$1:
	make -C $(_BUILDENV_DIR) binfmt
	for pkg in `cat packages/order.$1`; do \
		make build BOARD=$1 PKG=$$$$pkg || exit 1; \
	done
endef
$(foreach board,$(_KNOWN_BOARDS),$(eval $(call make_packages_board_target,$(board))))
packages: $(addprefix packages-,$(_KNOWN_BOARDS))


build:
	$(call say,"Ensuring package $(PKG) for $(BOARD)")
	rm -rf $(_BUILD_DIR)
	make _run BOARD=$(BOARD) CMD="/tools/buildpkg $(PKG) '$(call optbool,$(FORCE))' '$(call optbool,$(NOREPO))'"
	$(call say,"Complete package $(PKG) for $(BOARD)")


shell:
	make _run BOARD=$(BOARD) CMD=/bin/bash OPTS=-i


binfmt:
	make -C $(_BUILDENV_DIR) binfmt


buildenv: $(_BUILDENV_DIR)
	$(call say,"Ensuring $(BOARD) buildenv")
	make -C $(_BUILDENV_DIR) binfmt
	rm -rf $(_BUILDENV_DIR)/stages/buildenv
	cp -a buildenv $(_BUILDENV_DIR)/stages/buildenv
	make -C $(_BUILDENV_DIR) os \
		NC=$(NC) \
		PASS_ENSURE_TOOLBOX=1 \
		PASS_ENSURE_BINFMT=1 \
		BUILD_OPTS=" \
			--build-arg REPO_NAME=$(_REPO_NAME) \
			--build-arg REPO_KEY=$(_REPO_KEY) \
			--tag $(_BUILDENV_IMAGE) \
		" \
		PROJECT=pikvm-packages \
		BOARD=$(BOARD) \
		STAGES="__init__ buildenv" \
		HOSTNAME=buildenv
	$(call say,"Buildenv $(BOARD) is ready")


push:
	docker push $(_BUILDENV_IMAGE)


pull:
	docker pull $(_BUILDENV_IMAGE)


# =====
_run: $(_BUILD_DIR) $(_REPO_DIR)
	$(if $(patsubst 1000,,$(shell id -u)),$(call die,"Only user with UID=1000 can build packages"),)
	docker run \
			--rm \
			--tty \
			--interactive \
			--privileged \
			--volume `pwd`/$(_REPO_DIR):/repo:rw \
			--volume `pwd`/$(_BUILD_DIR):/build:rw \
			--volume `pwd`/packages:/packages:ro \
			--env REPO_DIR=/repo \
			--env BUILD_DIR=/build \
			--env PACKAGES_DIR=/packages \
			--volume $$HOME/.gnupg/:/home/alarm/.gnupg/:rw \
			--volume /run/user/1000/gnupg:/run/user/1000/gnupg:rw \
			$(OPTS) \
		$(_BUILDENV_IMAGE) \
		$(if $(CMD),$(CMD),/bin/bash)


$(_BUILDENV_DIR):
	git clone --depth=1 https://github.com/pikvm/pi-builder $(_BUILDENV_DIR)


$(_BUILD_DIR):
	mkdir -p $(_BUILD_DIR)


$(_REPO_DIR):
	mkdir -p $(_REPO_DIR)


.PHONY: buildenv packages repos
