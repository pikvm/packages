#!/usr/bin/make -f


__UPDATABLE := $(addprefix __update__, \
					$(subst \
						/update.mk, \
						, \
						$(subst \
							packages/, \
							, \
							$(wildcard packages/*/update.mk) \
						) \
					) \
				)

update: $(__UPDATABLE)

$(__UPDATABLE):
	$(MAKE) -C packages/$(subst __update__,,$@) -f update.mk update
