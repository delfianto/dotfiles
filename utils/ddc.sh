#!/usr/bin/env zsh
# helper script for switching monitor input using ddcutil.

BUS="${HOME}/.config/ddc_bus"

if [[ -s $BUS ]] || [[ ! -f $BUS ]]; then
echo 'Woof'
echo $BUS
exit 2
fi

FOO=$(sudo ddcutil detect | grep -B3 'LG HDR 4K' | head -1 | gawk 'match($0, /\/dev\/i2c-(.*)/, a) {print a[1]}')
echo $BUS
echo $FOO
