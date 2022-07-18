#!/bin/sh

init() {
  if [[ -z "${0}"]]; then
    echo "Pass steam app id as first argument"
    exit 1
  fi

  WINEPREFIX=$PWD/pfx WINEARCH=win32 wineboot winecfg
  mkdir $PWD/pfx/drive_c/windows/syswow64
}
