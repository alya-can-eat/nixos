
{ config, lib, pkgs, ... }:

### Written by hand, matching 'install/partition_ps4.bash' ###
# USB SSD, MBR:
#   1: FAT32 'FATTY_BOOT'  -> /boot (the payload reads bzImage, initramfs.cpio.gz, bootargs.txt from here)
#   2: LVM 'FATTY_lvm'     -> FATTY_swap + FATTY_rootfs (btrfs, same subvolumes as the other hosts)

{
  boot.initrd.availableKernelModules = [ ]; # nearly everything is built into the PS4 kernel
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/FATTY_lvm-FATTY_rootfs";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/home" =
    { device = "/dev/mapper/FATTY_lvm-FATTY_rootfs";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/mapper/FATTY_lvm-FATTY_rootfs";
      fsType = "btrfs";
      options = [ "subvol=@nix" ];
    };

  fileSystems."/persist" =
    { device = "/dev/mapper/FATTY_lvm-FATTY_rootfs";
      fsType = "btrfs";
      options = [ "subvol=@persist" ];
    };

  fileSystems."/var/log" =
    { device = "/dev/mapper/FATTY_lvm-FATTY_rootfs";
      fsType = "btrfs";
      options = [ "subvol=@log" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/FATTY_BOOT";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices =
    [ { device = "/dev/mapper/FATTY_lvm-FATTY_swap"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
