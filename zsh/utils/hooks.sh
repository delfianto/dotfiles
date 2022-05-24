#!/bin/sh
#
# File /etc/libvirt/hooks/qemu; libvirt qemu hooks
# executed when a QEMU guest is started, stopped, or migrated
# more details can be found on https://libvirt.org/hooks.html

HOOK_LOG="${HOOK_LOG:-/var/log/libvirthook.log}"

case "${2}" in
'prepare')
  # before libvirt performs any resource labeling, and the hook
  # can allocate resources not managed by libvirt such as DRBD
  # or missing bridges
  ;;
'start')
  # after libvirt has finished labeling all resources,
  # but has not yet started the guest
  ;;
'started')
  # after the QEMU process has successfully started up
  if pid=$(pidof qemu-system-x86_64); then
    chrt -f -p 1 ${pid}
    echo "$(date) changing scheduling for pid ${pid}" >> "${HOOK_LOG}"
  fi
  ;;
'stopped')
  # when a QEMU guest is stopped, the hook is called before
  # libvirt restores any labels
  ;;
'release')
  # after libvirt has released all resources, the hook is called again,
  # to allow any additional resource cleanup
  ;;
'migrate')
  # at the beginning of incoming migration
  ;;
esac
