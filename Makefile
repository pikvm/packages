-include config.mk

export PROJECT ?= pikvm-packages
export BOARD ?= rpi2
export ARCH ?= arm
export STAGES ?= __init__ buildenv
export HOSTNAME = buildenv
export ARCH_DIST_REPO_URL ?= http://mirror.archlinuxarm.org/
export DOCKER ?= docker
export DISTCC_HOSTS ?=
export DISTCC_J ?=

export J ?= $(shell nproc)
export NC ?=
export NOINT ?=


# =====
_TARGET = $(BOARD)-$(ARCH)
_TARGET_REPO_NAME = pikvm
_TARGET_REPO_KEY = 912C773ABBD1B584

_ALARM_UID := $(shell id -u)
_ALARM_GID := $(shell id -g)

_BUILDENV_IMAGE = $(PROJECT).$(_TARGET).$(_ALARM_UID)-$(_ALARM_GID)
_BUILDENV_DIR = ./.pi-builder/$(_TARGET)
_BUILD_DIR = ./.build/$(_TARGET)
_BASE_REPOS_DIR = ./repos
_TARGET_REPO_DIR = $(_BASE_REPOS_DIR)/$(_TARGET)


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


build:
	test -n "$(PKG)"
	$(call say,"Ensuring package $(PKG) for $(_TARGET)")
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
	$(call say,"Complete package $(PKG) for $(_TARGET)")


shell: buildenv
	$(MAKE) _run \
		OPTS="--tty --interactive"


binfmt: $(_BUILDENV_DIR)
	$(MAKE) -C $(_BUILDENV_DIR) binfmt


buildenv: binfmt
	$(call say,"Ensuring $(_TARGET) buildenv")
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
	$(call say,"Buildenv $(_TARGET) is ready")
.PHONY: buildenv


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
