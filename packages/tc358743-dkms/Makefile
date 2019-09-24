KVERSION ?= $(shell uname -r)

_PKG = $(shell bash -c " \
	if [ -f /etc/mkinitcpio.d/linux-raspberrypi4.preset ]; then echo linux-raspberrypi4; \
	else echo linux-raspberrypi; \
	fi \
")
_PKG_COMMIT = $(shell \
	curl "https://api.github.com/repos/archlinuxarm/PKGBUILDs/commits?path=core/$(_PKG)/PKGBUILD" \
		| jq '.[] | "\(.sha) \(.commit.message)"' \
		| tr -d '"' \
		| grep $(subst -ARCH,,$(KVERSION)) \
		| awk '{print $$1}' \
)
_KERNEL_COMMIT = $(shell \
	curl "https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/$(_PKG_COMMIT)/core/$(_PKG)/PKGBUILD" \
		| grep -Po '_commit=[a-fA-F\d]+' \
		| sed 's/_commit=//g' \
)
_SRC_PREFIX = https://raw.githubusercontent.com/raspberrypi/linux/$(_KERNEL_COMMIT)/drivers/media/i2c/

obj-m += tc358743.o

all: .srcs
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) clean
	rm -f *.c *.h .srcs

.srcs:
	wget `echo -e 'tc358743_regs.h\ntc358743.c' | awk '{print "$(_SRC_PREFIX)" $$0;}'`
	touch .srcs
