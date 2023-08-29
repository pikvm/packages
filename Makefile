-include config.mk

export PROJECT ?= pikvm-packages
export BOARD ?= rpi2
export STAGES ?= __init__ buildenv
export HOSTNAME = buildenv
export REPO_URL ?= http://de3.mirror.archlinuxarm.org/

DEPLOY_USER ?= root

export J ?= 13
export NC ?=
export NOINT ?=


# =====
_TARGET_REPO_NAME = pikvm
_TARGET_REPO_KEY = 912C773ABBD1B584

_ALARM_UID := $(shell id -u)
_ALARM_GID := $(shell id -g)

_BUILDENV_IMAGE = $(PROJECT).$(BOARD).$(_ALARM_UID)-$(_ALARM_GID)
_BUILDENV_DIR = ./.pi-builder/$(BOARD)
_BUILD_DIR = ./.build/$(BOARD)
_BASE_REPOS_DIR = ./repos
_TARGET_REPO_DIR = $(_BASE_REPOS_DIR)/$(BOARD)


# =====
define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef

define say
@ tput bold
@ tput setaf 2
@ echo "===== $1 ====="
@ tput sgr0
endef


# =====
all:
	true


upload:
	rsync -rl --progress --delete $(_BASE_REPOS_DIR)/ $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch
	rsync -rl --progress --delete $(_BASE_REPOS_DIR)/ $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch-testing


download:
	rm -rf $(_BASE_REPOS_DIR)
	rsync -rl --progress $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch/ $(_BASE_REPOS_DIR)


__UPDATABLE := $(addprefix __update__,$(subst /update.mk,,$(subst packages/,,$(wildcard packages/*/update.mk))))
update: $(__UPDATABLE)
$(__UPDATABLE):
	$(MAKE) -C packages/$(subst __update__,,$@) -f update.mk update


__ORDER := $(addprefix __build__,$(shell cat packages/order.$(BOARD)))
build: buildenv $(__ORDER)
$(__ORDER):
	$(MAKE) _build BOARD=$(BOARD) PKG=$(subst __build__,,$@) J=$(J)
# XXX: DO NOT RUN BUILD TASKS IN PARALLEL MODE!!!
.NOTPARALLEL: build


_build:
	test -n "$(PKG)"
	$(call say,"Ensuring package $(PKG) for $(BOARD)")
	$(MAKE) _run \
		OPTS="--tty $(if $(call optbool,$(NOINT)),,--interactive)" \
		CMD="/tools/buildpkg \
			$(PKG) \
			'$(call optbool,$(FORCE))' \
			'$(call optbool,$(NOREPO))' \
			'$(call optbool,$(NOEXTRACT))' \
			'$(call optbool,$(NOSIGN))' \
		"
	$(call say,"Complete package $(PKG) for $(BOARD)")


shell: buildenv
	$(MAKE) _run \
		OPTS="--tty --interactive"


binfmt: $(_BUILDENV_DIR)
	$(MAKE) -C $(_BUILDENV_DIR) binfmt


buildenv: binfmt
	$(call say,"Ensuring $(BOARD) buildenv")
	rm -rf $(_BUILDENV_DIR)/stages/arch/buildenv
	cp -a buildenv $(_BUILDENV_DIR)/stages/arch/buildenv
	$(MAKE) -C $(_BUILDENV_DIR) os \
		PASS_ENSURE_TOOLBOX=1 \
		PASS_ENSURE_BINFMT=1 \
		TAG=$(_BUILDENV_IMAGE) \
		BUILD_OPTS=" \
			--build-arg TARGET_REPO_NAME=$(_TARGET_REPO_NAME) \
			--build-arg TARGET_REPO_KEY=$(_TARGET_REPO_KEY) \
			--build-arg ALARM_UID=$(_ALARM_UID) \
			--build-arg ALARM_GID=$(_ALARM_GID) \
		"
	$(call say,"Buildenv $(BOARD) is ready")


# =====
_run: $(_BUILD_DIR) $(_TARGET_REPO_DIR)
	docker run \
			--rm \
			--privileged \
			--volume `pwd`/$(_TARGET_REPO_DIR):/repo:rw \
			--volume `pwd`/$(_BUILD_DIR):/build:rw \
			--volume `pwd`/packages:/packages:ro \
			--env TARGET_REPO_DIR=/repo \
			--env PKG_BUILD_DIR=/build \
			--env PACKAGES_DIR=/packages \
			--env MAKE_J=$(J) \
			--volume $$HOME/.gnupg/:/home/alarm/.gnupg/:rw \
			--volume /run/user/$(_ALARM_UID)/gnupg:/run/user/$(_ALARM_UID)/gnupg:rw \
			$(OPTS) \
		$(_BUILDENV_IMAGE) \
		$(if $(CMD),$(CMD),/bin/bash)


$(_BUILDENV_DIR):
	git clone --depth=1 https://github.com/pikvm/pi-builder $(_BUILDENV_DIR)


$(_BUILD_DIR):
	mkdir -p $(_BUILD_DIR)


$(_BASE_REPOS_DIR)/rpi2:
	mkdir -p $(_BASE_REPOS_DIR)/rpi2
	ln -sf rpi2 $(_BASE_REPOS_DIR)/zero2w
	ln -sf rpi2 $(_BASE_REPOS_DIR)/rpi3
	ln -sf rpi2 $(_BASE_REPOS_DIR)/rpi2-arm
	ln -sf rpi2 $(_BASE_REPOS_DIR)/rpi3-arm
	ln -sf rpi2 $(_BASE_REPOS_DIR)/rpi4
	ln -sf rpi2 $(_BASE_REPOS_DIR)/rpi4-arm


# =====
.PHONY: buildenv
