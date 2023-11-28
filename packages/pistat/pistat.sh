#!/bin/bash
set -euo pipefail

if [ -t 1 ]; then
	color_comment=$(echo -e '\e[1;30m')
	color_value=$(echo -e '\e[1;35m')
	color_ok=$(echo -e '\e[1;32m')
	color_fail=$(echo -e '\e[1;31m')
	color_reset=$(echo -e '\e[0m')
else
	color_comment=""
	color_value=""
	color_ok=""
	color_fail=""
	color_reset=""
fi
no="${color_ok}no${color_reset}"
yes="${color_fail}yes${color_reset}"


# =====
echo "${color_comment}# $(tr -d '\0' < /proc/device-tree/model)${color_reset}"

echo
echo "CPU temp: ${color_value}$(bc -l <<< "scale=2; $(</sys/class/thermal/thermal_zone0/temp) / 1000")'C${color_reset}"
gpu_temp=$(/usr/bin/vcgencmd measure_temp)
echo "GPU temp: ${color_value}${gpu_temp#*=}${color_reset}"

flags=$(/usr/bin/vcgencmd get_throttled)
flags="${flags#*=}"
echo
echo "Throttled flags: ${color_value}${flags}${color_reset}"

echo
echo -n "Throttled now:  "
((($flags&0x4)!=0)) && echo $yes || echo $no

echo -n "Throttled past: "
((($flags&0x40000)!=0)) && echo $yes || echo $no

echo
echo -n "Undervoltage now:  "
((($flags&0x1)!=0)) && echo $yes || echo $no

echo -n "Undervoltage past: "
((($flags&0x10000)!=0)) && echo $yes || echo $no

echo
echo -n "Frequency capped now:  "
((($flags&0x2)!=0)) && echo $yes || echo $no

echo -n "Frequency capped past: "
((($flags&0x20000)!=0)) && echo $yes || echo $no


# =====
# https://stackoverflow.com/questions/13889659/read-a-file-by-bytes-in-bash
read8() {
	local _r8_var=${1:-OUTBIN} _r8_car LANG=C IFS=
	read -r -d '' -n 1 _r8_car
	printf -v $_r8_var %d "'"$_r8_car
}
read16() {
	local _r16_var=${1:-OUTBIN} _r16_lb _r16_hb
	read8  _r16_hb && read8  _r16_lb
	printf -v $_r16_var %d $(( _r16_hb<<8 | _r16_lb ))
}
read32() {
	local _r32_var=${1:-OUTBIN} _r32_lw _r32_hw
	read16 _r32_hw && read16 _r32_lw
	printf -v $_r32_var %d $(( _r32_hw<<16| _r32_lw ))
}

power=/proc/device-tree/chosen/power
if [ -f $power/max_current ]; then
	read32 value < $power/max_current
	echo
	echo "Max power supply current:" ${color_value}$(bc <<< "scale=1; $value / 1000")A${color_reset}
fi
if [ -f $power/usb_max_current_enable ]; then
	read32 value < $power/usb_max_current_enable
	echo "USB max current enabled: " ${color_value}$(test $value -ne 0 && echo yes || echo no)${color_reset}
fi
if [ -f $power/usb_over_current_detected ]; then
	read32 value < $power/usb_over_current_detected
	echo "USB overcurrent detected:" $(test $value -ne 0 && echo $yes || echo $no)
fi
