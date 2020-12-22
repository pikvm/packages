#!/usr/bin/env python3
# ========================================================================== #
#                                                                            #
#    KVMD-OLED - Small OLED daemon for Pi-KVM.                               #
#                                                                            #
#    Copyright (C) 2018  Maxim Devaev <mdevaev@gmail.com>                    #
#                                                                            #
#    This program is free software: you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation, either version 3 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License       #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.  #
#                                                                            #
# ========================================================================== #


import sys
import socket
import logging
import datetime
import time

from typing import Tuple

import netifaces
import psutil

from luma.core import cmdline 
from luma.core.render import canvas

from PIL import ImageFont


# =====
_logger = logging.getLogger("oled")


# =====
def _get_ip() -> Tuple[str, str]:
    try:
        gws = netifaces.gateways()
        if "default" not in gws:
            raise RuntimeError(f"No default gateway: {gws}")

        iface = ""
        for proto in [socket.AF_INET, socket.AF_INET6]:
            if proto in gws["default"]:
                iface = gws["default"][proto][1]
                break
        else:
            raise RuntimeError(f"No iface for the gateway {gws['default']}")

        for addr in netifaces.ifaddresses(iface).get(proto, []):
            return (iface, addr["addr"])
    except Exception:
        _logger.exception("Can't get iface/IP")
        return ("<no-iface>", "<no-ip>")


def _get_uptime() -> str:
    uptime = datetime.timedelta(seconds=int(time.time() - psutil.boot_time()))
    pl = {"days": uptime.days}
    (pl["hours"], rem) = divmod(uptime.seconds, 3600)
    (pl["mins"], pl["secs"]) = divmod(rem, 60)
    return "{days}d {hours}h {mins}m".format(**pl)


# =====
def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    logging.getLogger("PIL").setLevel(logging.ERROR)

    parser = cmdline.create_parser(description="Display FQDN and IP on the OLED")
    parser.add_argument("--font", default="/usr/share/fonts/TTF/ProggySquare.ttf", help="Font path")
    parser.add_argument("--font-size", default=16, type=int, help="Font size")
    parser.add_argument("--interval", default=5, type=int, help="Screens interval")
    options = parser.parse_args(sys.argv[1:])
    if options.config:
        config = cmdline.load_config(options.config)
        options = parser.parse_args(config + sys.argv[1:])

    device = cmdline.create_device(options)
    font = ImageFont.truetype(options.font, options.font_size)

    display_types = cmdline.get_display_types()
    if options.display not in cmdline.get_display_types()["emulator"]:
        _logger.info("Iface: %s", options.interface)
    _logger.info("Display: %s", options.display)
    _logger.info("Size: %dx%d", device.width, device.height)

    try:
        summary = True
        while True:
            with canvas(device) as draw:
                if summary:
                    text = f"{socket.getfqdn()}\nUp: {_get_uptime()}"
                else:
                    text = f"Iface: %s\n%s" % (_get_ip())
                draw.multiline_text((0, 0), text, font=font, fill="white")
                summary = (not summary)
                time.sleep(options.interval)
    except (SystemExit, KeyboardInterrupt):
        pass


if __name__ == "__main__":
    main()
