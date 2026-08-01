#!/usr/bin/make -f

-include config.mk


# =====
all:

.all_targets.mk: print_targets.py build_all.mk
	./print_targets.py > .all_targets.mk.tmp
	mv .all_targets.mk.tmp .all_targets.mk

include .all_targets.mk

all: $(ALL_PKG_TARGETS)
.NOTPARALLEL: all $(ALL_PKG_TARGETS) $(ALL_BA_TARGETS)

.SECONDEXPANSION:
$(ALL_PKG_TARGETS):
	@ tput -Txterm bold
	@ tput -Txterm setab 5
	@ tput -Txterm setaf 15
	@ echo -n "========== $@ =========="
	@ tput -Txterm sgr0
	@ echo
	$(MAKE) build PKG=`basename $@`

$(ALL_BA_TARGETS):
	$(MAKE) buildenv
