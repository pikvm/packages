-include config.mk

export PROJECT ?= pikvm-packages
export BOARD ?= rpi2
export STAGES ?= __init__ buildenv
export HOSTNAME = buildenv
export ARCH_DIST_REPO_URL ?= http://mirror.archlinuxarm.org/
export DOCKER ?= docker
export DISTCC_HOSTS ?=
export DISTCC_J ?=
UPLOAD ?= testing stable

DEPLOY_USER ?= root

export J ?= $(shell nproc)
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


__upload__testing:
	rsync -rl --progress --delete $(_BASE_REPOS_DIR)/ $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch-testing
__upload__stable:
	rsync -rl --progress --delete $(_BASE_REPOS_DIR)/ $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch
upload: $(addprefix __upload__,$(UPLOAD))


download:
	rm -rf $(_BASE_REPOS_DIR)
	rsync -rl --progress $(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/repos/arch/ $(_BASE_REPOS_DIR)


__UPDATABLE := $(addprefix __update__,$(subst /update.mk,,$(subst packages/,,$(wildcard packages/*/update.mk))))
update: $(__UPDATABLE)
$(__UPDATABLE):
	$(MAKE) -C packages/$(subst __update__,,$@) -f update.mk update


__BUILD_ORDER := $(addprefix __build__,$(shell cat packages/order.$(BOARD)))
build: buildenv $(__BUILD_ORDER)
$(__BUILD_ORDER):
	$(MAKE) _build BOARD=$(BOARD) PKG=$(subst __build__,,$@)
# XXX: DO NOT RUN BUILD TASKS IN PARALLEL MODE!!!


_build:
	test -n "$(PKG)"
	$(call say,"Ensuring package $(PKG) for $(BOARD)")
	$(MAKE) _run \
		OPTS="--shm-size=4gb --tty $(if $(call optbool,$(NOINT)),,--interactive)" \
		CMD="/tools/buildpkg \
			$(if $(call optbool,$(FORCE)),--force,) \
			$(if $(call optbool,$(NOREPO)),--no-repo,) \
			$(if $(call optbool,$(NOEXTRACT)),--no-extract,) \
			$(if $(call optbool,$(NOSIGN)),--no-sign,) \
			$(if $(DISTCC_HOSTS),--distcc-hosts $(DISTCC_HOSTS),) \
			$(if $(DISTCC_J),--distcc-make-j $(DISTCC_J),) \
			--make-j $(J) \
			$(PKG) \
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
	$(DOCKER) run \
			--rm \
			--privileged \
			--ulimit "nofile=65536:1048576" \
			--volume $(shell pwd)/$(_TARGET_REPO_DIR):/repo:rw \
			--volume $(shell pwd)/$(_BUILD_DIR):/build:rw \
			--volume $(shell pwd)/packages:/packages:ro \
			--env TARGET_REPO_DIR=/repo \
			--env BUILD_DIR=/build \
			--env PACKAGES_DIR=/packages \
			--volume $$HOME/.gnupg/:/home/alarm/.gnupg/:rw \
			--volume /run/user/$(_ALARM_UID)/gnupg:/run/user/$(_ALARM_UID)/gnupg:rw \
			--mount type=tmpfs,destination=/tmp \
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
.NOTPARALLEL:
