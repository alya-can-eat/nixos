#!/usr/bin/env bash
set -euo pipefail

### Prepare a USB SSD for the PS4 (host 'fatty') and install NixOS onto it ###
# Run on the PC from the root of this repo:  sudo ./install/partition_ps4.bash
# Same layout as partition.bash (LVM + btrfs subvolumes for impermanence), but:
#   - whole disk, MBR, first partition FAT32 (the PS4 payload reads the kernel from there)
#   - LVM is called FATTY_lvm so it can't clash with the PC's own GLaDOS_lvm
#   - no LUKS (nothing to type the passphrase into before the payload boots Linux)

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root!"
  exit 1
fi

mountpoint -q /mnt && { echo "/mnt is mounted! aborting"; exit 1; }
[[ -f flake.nix && -d hosts/ps4 ]] || { echo "Run this from the root of the NixOS config repo! aborting"; exit 1; }

LABEL_ROOTFS="FATTY"
FLAKE_HOST="fatty"

echo "Before you continue:"
echo " - new files must be committed or 'git add'ed, flakes ignore untracked files"
read -p "Press Enter to continue..."

echo ""
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,MOUNTPOINTS
echo ""
read -r -p "Enter the WHOLE DISK of the PS4 SSD (example: /dev/sdx): " DISK
[[ -b "$DISK" ]] || { echo "Error: $DISK is not a valid block device"; exit 1; }
[[ "$(lsblk -dno TYPE "$DISK")" == "disk" ]] || { echo "Error: $DISK is not a whole disk"; exit 1; }

echo ""
read -r -p "Enter size for 'swap' in MiB (GB*1024MiB): " SIZE_SWAP
[[ "$SIZE_SWAP" =~ ^[0-9]+$ ]] || { echo "Error: '$SIZE_SWAP' is not a number"; exit 1; }

if [[ "$DISK" =~ [0-9]$ ]]; then PART="${DISK}p"; else PART="$DISK"; fi
PARTITION_BOOT="${PART}1"
PARTITION_LVM="${PART}2"

echo ""
lsblk "$DISK"
echo "THE WHOLE DISK $DISK WILL BE WIPED!!!"
read -r -p "Type 'YES' to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || { echo "Aborted."; exit 1; }



echo ""
echo "Partitioning $DISK (MBR: FAT32 boot 2048 MiB + LVM)"
for p in "$DISK"?*; do umount "$p" 2>/dev/null || true; done
wipefs -a "$DISK"
parted -s "$DISK" -- mklabel msdos \
  mkpart primary fat32 1MiB 2049MiB \
  mkpart primary 2049MiB 100% \
  set 2 lvm on
partprobe "$DISK"
udevadm settle
wipefs -a "$PARTITION_BOOT" "$PARTITION_LVM"

echo ""
echo "Formatting $PARTITION_BOOT"
mkfs.fat -F32 -n "${LABEL_ROOTFS}_BOOT" "$PARTITION_BOOT"

echo ""
echo "Creating LVM"
pvcreate "$PARTITION_LVM"
vgcreate "$LABEL_ROOTFS"_lvm "$PARTITION_LVM"

echo ""
echo "Create SWAP"
lvcreate -y -L "$SIZE_SWAP"M -n "$LABEL_ROOTFS"_swap "$LABEL_ROOTFS"_lvm
mkswap -L "$LABEL_ROOTFS"_swap /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_swap

echo ""
echo "Create rootfs"
lvcreate -y -l '100%FREE' -n "$LABEL_ROOTFS"_rootfs "$LABEL_ROOTFS"_lvm
mkfs.btrfs -L "$LABEL_ROOTFS" /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs

echo ""
echo "Create btrfs subvolumes in rootfs"
mount /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persist
btrfs subvolume create /mnt/@log
btrfs subvolume snapshot -r /mnt/@ /mnt/@fresh
umount /mnt

echo ""
echo "Mounting"
mount -o compress=zstd,subvol=@ /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt
mkdir /mnt/home
mkdir /mnt/nix
mkdir /mnt/persist
mkdir /mnt/var
mkdir /mnt/var/log
mount -o compress=zstd,subvol=@home /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt/home
mount -o compress=zstd,noatime,subvol=@nix /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt/nix
mount -o compress=zstd,subvol=@persist /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt/persist
mount -o compress=zstd,subvol=@log /dev/"$LABEL_ROOTFS"_lvm/"$LABEL_ROOTFS"_rootfs /mnt/var/log
mkdir /mnt/boot
mount "$PARTITION_BOOT" /mnt/boot

echo ""
echo "Preparing /persist for impermanence (see install/impermanence/README.txt)"
mkdir -p /mnt/persist/etc
dbus-uuidgen --ensure=/mnt/persist/etc/machine-id
cp -a "$PWD" /mnt/persist/etc/nixos
chown -R 1000:100 /mnt/persist/etc/nixos

echo ""
echo "Installing NixOS ($FLAKE_HOST). This builds the PS4 kernel and Mesa, it takes a while."
nixos-install --flake ".#$FLAKE_HOST" --root /mnt --no-root-passwd

echo ""
echo "Set a password for alya (needed for sudo and SSH):"
nixos-enter --root /mnt -c 'passwd alya'
cp /mnt/etc/shadow /mnt/persist/etc/shadow

echo ""
echo "Unmounting"
umount -R /mnt
vgchange -an "$LABEL_ROOTFS"_lvm

echo ""
echo "DONE! The FAT32 partition now holds bzImage, initramfs.cpio.gz, bootargs.txt and vram.txt."
echo "Plug the SSD into the PS4, run the exploit and the Linux payload."
echo "If it doesn't boot: compare /proc/cmdline of a working community distro with bootargs.txt"
echo "and add what's missing to boot.kernelParams in hosts/ps4/_boot.nix."
echo ""
read -p "Press Enter to exit..."
exit
