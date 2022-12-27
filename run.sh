#!/bin/bash
#
# Run a VM image using UEFI as simply as possible

set -eu
set -x

# uefi firmware and store
OVMF_DIR=/usr/share/OVMF/
[ -e ovmf_code.fd ] || cp -v "${OVMF_DIR}/OVMF_CODE.fd" ovmf_code.fd
[ -e var_store.fd ] || cp -v "${OVMF_DIR}/OVMF_VARS.fd" var_store.fd
chmod -w ovmf_code.fd
chmod +w var_store.fd

# boot image; Debian 11 specific for now
if [ ! -e boot0.qcow2 ] ; then
  VMIMG=https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-nocloud-amd64.tar.xz
  fn=$(basename "$VMIMG")
  wget -cS $VMIMG
  tar --sparse -xvf "$fn"
  qemu-img convert -p disk.raw -c -O qcow2 orig.qcow2
  qemu-img create -f qcow2 -b orig.qcow2 -F qcow2 boot0.qcow2
  rm -f "$fn" disk.raw
fi

# see README.md
mkdir -p guestshare/

# pass control-c to qemu (not the controlling terminal)
stty intr '^]'

qemu-system-x86_64 \
    \
    -machine q35,accel=kvm \
    -smp 4 -m 4096 \
    -cpu host,+x2apic \
    -vga virtio \
    -watchdog i6300esb \
    -parallel none \
    -device qemu-xhci,id=xhci -device usb-tablet,bus=xhci.0 \
    \
    -drive if=pflash,format=raw,readonly,file=ovmf_code.fd \
    -drive if=pflash,format=raw,file=var_store.fd \
    -boot splash-time=30 \
    -boot menu=on \
    -smbios type=1,manufacturer=cwcorp,product=cwmachine,version=3.14,serial=2718,uuid=247a6c78-422c-4bb7-8e72-8c90c81261d4,sku=skewSKU,family=elvesFamily \
    \
    -netdev user,id=n1 -device virtio-net-pci,netdev=n1 \
    \
    -device virtio-scsi-pci,id=scsi0 \
    -drive if=none,file="boot0.qcow2",id=dsk1,format=qcow2,discard=unmap,cache=directsync,aio=native \
    -device scsi-hd,drive=dsk1,discard_granularity=512 \
    \
    -fsdev local,id=fs1,path=guestshare/,security_model=mapped \
    -device virtio-9p-pci,fsdev=fs1,mount_tag=share0 \
    \
    -vnc :99 \
    \
    -serial stdio

# put C-c back to how we expect things
stty intr '^C'
# needed because qemu will do other things to the terminal that leave
# it in a bad state
stty sane
echo -e '\x1bc'
clear

exit 0
