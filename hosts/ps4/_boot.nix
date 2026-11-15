
{ config, pkgs, lib, ... }:

### Boot through the PS4 Linux payload ###
# The payload (ps4boot/ps4-linux-payloads, fw1150/payload-1150-1gb for fatty) kexecs into
# whatever it finds on the FAT32 USB drive: bzImage + initramfs.cpio.gz, kernel cmdline
# from bootargs.txt, VRAM size from vram.txt. There is no boot menu, so this hook just
# writes the current generation there and keeps the previous one as *.prev.
# The payload also dumps the GPU firmware and EDID from Orbis and puts them in front of
# our initramfs as lib/firmware/amdgpu/liverpool_*.bin and lib/firmware/edid/my_edid.bin.
# Rollback if a generation doesn't boot: plug the SSD into the PC and copy the
# *.prev files back over the normal ones (don't garbage collect that generation).

let
  # Careful, the unit depends on the payload: ps4boot reads GB (1 ... 5) and falls back
  # to 1 GB on anything else, ArabPixel's fork reads MB (32 ... 4096).
  # 1024 means 1 GB with both.
  vramMB = 1024;

  installHook = pkgs.writeShellScript "ps4-install-bootloader" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}
    sys="$1"
    boot=/boot

    for f in bzImage initramfs.cpio.gz bootargs.txt; do
      if [ -e "$boot/$f" ]; then cp "$boot/$f" "$boot/$f.prev"; fi
    done

    cp "$sys/kernel" "$boot/bzImage.tmp"
    cp "$sys/initrd" "$boot/initramfs.cpio.gz.tmp"
    mv "$boot/bzImage.tmp" "$boot/bzImage"
    mv "$boot/initramfs.cpio.gz.tmp" "$boot/initramfs.cpio.gz"
    echo "init=$sys/init $(cat "$sys/kernel-params")" > "$boot/bootargs.txt"
    echo "${toString vramMB}" > "$boot/vram.txt"
    sync
  '';
in

{
  boot = {
    loader = {
      grub.enable = lib.mkForce false; # modules/boot.nix turns GRUB on for every host
      external = {
        enable = true;
        inherit installHook;
      };
    };
    initrd = {
      compressor = "gzip";           # the kernel has no CONFIG_RD_ZSTD (NixOS default is zstd)
      includeDefaultModules = false; # the default list is for PCs; the PS4 drivers are built in
      allowMissingModules = true;    # shared modules may ask for modules this kernel doesn't build
      # NixOS makes /lib in the initrd a symlink. The payload's firmware archive is unpacked
      # first and creates /lib as a real directory, so that symlink would silently fail and
      # /lib/modules would be missing. Make /lib a directory and only link /lib/modules;
      # /lib/firmware then is the payload's, which amdgpu needs (it's built in and loads its
      # firmware before the real root is mounted).
      systemd.contents = {
        "/lib".enable = false;
        "/lib/modules".source = "${config.system.build.modulesClosure}/lib/modules";
      };
    };
    # bootargs.txt REPLACES the payload's built-in cmdline, so repeat it here
    # (default from ps4boot/ps4-linux-payloads linux/main.c).
    kernelParams = [
      "panic=0"         # stay on the panic message instead of rebooting
      "clocksource=tsc"
      "consoleblank=0"
      "net.ifnames=0"
      "radeon.dpm=0"
      "amdgpu.dpm=0"
      "drm.debug=0"
      "console=ttyS0,115200n8"
      "console=tty0"    # last console= wins: /dev/console is the screen
      "video=HDMI-A-1:1920x1080@60"
    ];
  };

  hardware.firmwareCompression = "xz"; # the kernel has no zstd firmware loader (NixOS default is zstd)
}
