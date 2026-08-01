#!/usr/bin/make -f

-include config.mk

UPLOAD_USER ?= root
UPLOAD_DEST ?= files.pikvm.org:/var/www/files.pikvm.org/repos
UPLOAD_STABLE ?= $(UPLOAD_DEST)/arch
UPLOAD_TESTING ?= $(UPLOAD_DEST)/arch-testing

TARGETS := rpi2-arm rpi4-aarch64


# =====
all:
	true


__DL_TARGETS := $(addprefix download_,$(TARGETS))
download: $(__DL_TARGETS)
$(__DL_TARGETS): repos
	$(eval _target := $(subst download_,,$@))
	rsync -rl --progress \
		$(UPLOAD_USER)@$(UPLOAD_STABLE)/$(_target)/ \
		repos/$(_target)
repos:
	mkdir -p repos


__UP_TESTING := $(addprefix upload_testing_,$(TARGETS))
upload_testing: $(__UP_TESTING)
$(__UP_TESTING):
	$(eval _target := $(subst upload_testing_,,$@))
	rsync -rl --progress --delete \
		repos/$(_target)/ \
		$(UPLOAD_USER)@$(UPLOAD_TESTING)/$(_target)

__UP_STABLE := $(addprefix upload_stable_,$(TARGETS))
upload_stable: $(__UP_STABLE)
$(__UP_STABLE):
	$(eval _target := $(subst upload_stable_,,$@))
	rsync -rl --progress --delete \
		repos/$(_target)/ \
		$(UPLOAD_USER)@$(UPLOAD_STABLE)/$(_target)

upload: upload_testing upload_stable
