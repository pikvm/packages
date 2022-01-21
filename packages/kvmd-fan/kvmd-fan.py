#!/usr/bin/env python3
# ========================================================================== #
#                                                                            #
#    KVMD-FAN - A small fan controller daemon.                               #
#                                                                            #
#    Copyright (C) 2018-2022  Maxim Devaev <mdevaev@gmail.com>               #
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


import ctypes
import ctypes.util
import argparse
import time

from typing import Optional


# =====
class _Fan:
    def set_speed(self, speed: float) -> None:  # Percent
        raise NotImplementedError


class _PwmFan:
    __libwpi: Optional[ctypes.CDLL] = None

    def __init__(self, pin: int) -> None:
        if self.__libwpi is None:
            type(self).__libwpi = self.__load_wiringpi()
            if self.__libwpi.wiringPiSetupGpio() != 0:
                raise RuntimeError("Can't setup GPIO")
        self.__pin = pin
        # https://github.com/WiringPi/WiringPi/blob/master/wiringPi/wiringPi.h
        self.__libwpi.pinMode(pin, 2)  # PWM_OUTPUT == 2

    def set_speed(self, speed: float) -> None:
        assert type(self).__libwpi
        pwm = min(max(int(1024 * speed // 100), 0), 1024)
        self.__libwpi.pwmWrite(self.__pin, pwm)

    def __load_wiringpi(self) -> ctypes.CDLL:
        # http://wiringpi.com/reference/setup
        # http://wiringpi.com/reference/core-functions
        path = ctypes.util.find_library("wiringPi")
        if not path:
            raise RuntimeError("Where is libwiringPi?")
        assert path
        lib = ctypes.CDLL(path)
        for (name, restype, argtypes) in [
            ("wiringPiSetupGpio", ctypes.c_int, []),
            ("pinMode", None, [ctypes.c_int, ctypes.c_int]),
            ("pwmWrite", None, [ctypes.c_int, ctypes.c_int]),
        ]:
            func = getattr(lib, name)
            if not func:
                raise RuntimeError(f"Where is libwiringPi.{name}?")
            setattr(func, "restype", restype)
            setattr(func, "argtypes", argtypes)
        return lib


def _get_temp() -> float:
    with open("/sys/class/thermal/thermal_zone0/temp") as temp_file:
        return int((temp_file.read().strip())) / 1000


def _remap(value: float, in_min: float, in_max: float, out_min: float, out_max: float) -> float:
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min


def _run(
    fan: _Fan,
    temp_min: float,
    temp_max: float,
    speed_min: float,
    speed_max: float,
    temp_hyst: float,
    speed_idle: float,
    speed_heat: float,
    speed_spin_up: float,
    interval: float,
) -> None:

    prev_temp = 0.0
    prev_speed = 0.0
    while True:
        temp = _get_temp()
        if abs(abs(prev_temp) - abs(temp)) >= temp_hyst:
            if temp < temp_min:
                speed = speed_idle
            elif temp > temp_max:
                speed = speed_heat
            else:
                speed = _remap(temp, temp_min, temp_max, speed_min, speed_max)
            if (prev_speed < speed_idle or prev_speed == 0) and speed > 0:
                fan.set_speed(speed_spin_up)
                time.sleep(2)
            fan.set_speed(speed)
            prev_temp = temp
            prev_speed = speed
        time.sleep(interval)


# =====
def main() -> None:
    parser = argparse.ArgumentParser(
        prog="kvmd-fan",
        description="A small fan controller daemon",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--pwm-pin",       default=12,    type=int,   metavar="PIN",     help="GPIO pin for PWM DC fan")
    parser.add_argument("--temp-min",      default=45.0,  type=float, metavar="CELSIUS", help="Lower temp range limit")
    parser.add_argument("--temp-max",      default=75.0,  type=float, metavar="CELSIUS", help="Upper temp range limit")
    parser.add_argument("--speed-min",     default=25.0,  type=float, metavar="PERCENT", help="Lower fan speed range limit")
    parser.add_argument("--speed-max",     default=75.0,  type=float, metavar="PERCENT", help="Upper fan speed range limit")
    parser.add_argument("--temp-hyst",     default=1.0,   type=float, metavar="CELSIUS", help="Temp hysteresis")
    parser.add_argument("--speed-idle",    default=25.0,  type=float, metavar="PERCENT", help="Fan speed out of range")
    parser.add_argument("--speed-heat",    default=100.0, type=float, metavar="PERCENT", help="Fan speed on overheating")
    parser.add_argument("--speed-spin-up", default=75.0,  type=float, metavar="PERCENT", help="Fan speed for spin-up")
    parser.add_argument("--interval",      default=1.0,   type=float, metavar="SECONDS", help="Temp monitoring interval")
    options = parser.parse_args()
    assert options.pwm_pin >= 0
    assert 0 <= options.temp_hyst < options.temp_min < options.temp_max <= 85
    assert 0 <= options.speed_idle <= options.speed_min < options.speed_max <= options.speed_heat <= 100
    assert options.interval >= 1

    fan = _PwmFan(options.pwm_pin)
    try:
        _run(
            fan=fan,
            **{
                key: getattr(options, key)
                for key in [
                    "temp_min", "temp_max",
                    "speed_min", "speed_max",
                    "temp_hyst", "speed_idle", "speed_heat", "speed_spin_up",
                    "interval",
                ]
            },
        )
    except (SystemExit, KeyboardInterrupt):
        pass
    finally:
        fan.set_speed(100.0)


if __name__ == "__main__":
    main()
