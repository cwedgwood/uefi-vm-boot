# uefi-vm-boot

trimmed down/tweaked version of something used elsewhere, shared for
those who are asking

## mounting `guestshare/`

	mount -t 9p -o trans=virtio,msize=256K share0 /mnt/
