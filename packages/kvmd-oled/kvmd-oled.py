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

from luma.core import cmdline as luma_cmdline
from luma.core.device import device as luma_device
from luma.core.render import canvas as luma_canvas

from PIL import Image
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
        # _logger.exception("Can't get iface/IP")
        return ("<no-iface>", "<no-ip>")


def _get_uptime() -> str:
    uptime = datetime.timedelta(seconds=int(time.time() - psutil.boot_time()))
    pl = {"days": uptime.days}
    (pl["hours"], rem) = divmod(uptime.seconds, 3600)
    (pl["mins"], pl["secs"]) = divmod(rem, 60)
    return "{days}d {hours}h {mins}m".format(**pl)


def _draw_text(device: luma_device, font: ImageFont.FreeTypeFont, offset: Tuple[int, int], text: str) -> None:
    with luma_canvas(device) as draw:
        draw.multiline_text(offset, text, font=font, fill="white")


def _draw_image(device: luma_device, offset: Tuple[int, int], image_path: str) -> None:
    with luma_canvas(device) as draw:
        draw.bitmap(offset, Image.open(image_path).convert("1"), fill="white")


# =====
def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    logging.getLogger("PIL").setLevel(logging.ERROR)

    parser = luma_cmdline.create_parser(description="Display FQDN and IP on the OLED")
    parser.add_argument("--font", default="/usr/share/fonts/TTF/ProggySquare.ttf", help="Font path")
    parser.add_argument("--font-size", default=16, type=int, help="Font size")
    parser.add_argument("--offset-x", default=0, type=int, help="Horizontal offset")
    parser.add_argument("--offset-y", default=0, type=int, help="Vertical offset")
    parser.add_argument("--interval", default=5, type=int, help="Screens interval")
    parser.add_argument("--image", default="", help="Display some image, wait a single interval and exit")
    parser.add_argument("--text", default="", help="Display some text, wait a single interval and exit")
    parser.add_argument("--pipe", action="store_true", help="Read and display lines from stdin until EOF, wait a single interval and exit")
    parser.add_argument("--clear-on-exit", action="store_true", help="Clear display on exit")
    options = parser.parse_args(sys.argv[1:])
    if options.config:
        config = luma_cmdline.load_config(options.config)
        options = parser.parse_args(config + sys.argv[1:])

    device = luma_cmdline.create_device(options)
    device.cleanup = (lambda _: None)
    offset = (options.offset_x, options.offset_y)
    font = ImageFont.truetype(options.font, options.font_size)

    display_types = luma_cmdline.get_display_types()
    if options.display not in luma_cmdline.get_display_types()["emulator"]:
        _logger.info("Iface: %s", options.interface)
    _logger.info("Display: %s", options.display)
    _logger.info("Size: %dx%d", device.width, device.height)

    try:
        if options.image:
            _draw_image(device, offset, options.image)
            time.sleep(options.interval)

        elif options.text:
            _draw_text(device, font, offset, options.text.replace("\\n", "\n"))
            time.sleep(options.interval)

        elif options.pipe:
            text = ""
            for line in sys.stdin:
                text += line
                if "\0" in text:
                    _draw_text(device, font, offset, text.replace("\0", ""))
                    text = ""
            time.sleep(options.interval)

        else:
            summary = True
            while True:
                if summary:
                    text = f"{socket.getfqdn()}\nUp: {_get_uptime()}"
                else:
                    text = f"Iface: %s\n%s" % (_get_ip())
                _draw_text(device, font, offset, text)
                summary = (not summary)
                time.sleep(max(options.interval, 1))
    except (SystemExit, KeyboardInterrupt):
        pass

    if options.clear_on_exit:
        _draw_text(device, font, offset, "")


if __name__ == "__main__":
    main()
