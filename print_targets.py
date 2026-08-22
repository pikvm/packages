#!/usr/bin/env python


# =====
_PKGS = [
    "libimobiledevice-glue-git",
    "libplist-git",
    "libtatsu-git",
    "libusbmuxd-git",
    "libirecovery-git",
    "libimobiledevice-git",
    "idevicerestore-git",
    "usbmuxd-git",
    "linux-api-headers-pikvm",
    "linux-firmware-pikvm",
    "firmware-raspberrypi-pikvm",
    "raspberrypi-bootloader-pikvm",
    "linux-rpi-pikvm",
    "pistat",
    "pikvm-os-ro",
    "pikvm-os-updater",
    "pikvm-os-raspberrypi",
    "mkinitcpio-rootdelay",
    "janus-gateway-pikvm",
    "watchdog",
    "tailscale-pikvm",
    "python-pyserial-asyncio",
    "python-pyghmi",
    "python-pyftdi",
    "python-spidev",
    "python-smbus2",
    "python-luma-core",
    "python-luma-oled",
    "python-luma-lcd",
    "python-pyrad",
    "raspberrypi-io-access",
    "raspberrypi-bluetooth",
    "flashrom-pikvm",
    "ustreamer",
    "ucamera",
    "picotool",
    "kvmd",
    "kvmd-oidc",
    "kvmd-webterm",
    "kvmd-fan",
    "kvmd-cloud",
    "vi-vim-symlink",
]


# =====
def main() -> None:
    ba_targets: list[str] = []
    pkg_targets: list[str] = []
    for (board, arch) in [("rpi2", "arm"), ("rpi4", "aarch64")]:
        ba = f"{board}-{arch}"
        print(f"{ba}: export BOARD={board}")
        print(f"{ba}: export ARCH={arch}")
        print(f".PHONY: {ba}")
        print()
        ba_targets.append(ba)
        for pkg in _PKGS:
            ba_pkg = f"{ba}/{pkg}"
            print(f"{ba_pkg}: export BOARD={board}")
            print(f"{ba_pkg}: export ARCH={arch}")
            print(f"{ba_pkg}: {ba}")
            print(f".PHONY: {ba_pkg}")
            print()
            print(f"{pkg}: {ba_pkg}")
            print(f".PHONY: {pkg}")
            print()
            pkg_targets.append(ba_pkg)
    print()
    print(f"ALL_BA_TARGETS := {' '.join(ba_targets)}")
    print(f"ALL_PKG_TARGETS := {' '.join(pkg_targets)}")


if __name__ == "__main__":
    main()
