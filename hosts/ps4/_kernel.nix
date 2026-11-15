
{ config, pkgs, lib, ps4pkgs, ps4-kernel-aeolia-belize, ... }:

### PS4 kernel: feeRnt/ps4-linux-12xx, flake input 'ps4-kernel-aeolia-belize' ###
# Branch 6.15.4-aeolia-belize-crashniels = Aeolia/Belize only (fatty is a CUH-1116A, Aeolia).
# Baikal consoles (most Slims and Pros) need a different branch and probably more work.
#
# The repo ships a working 'config'. Changes made here:
#   - CONFIG_EXTRA_FIRMWARE_DIR pointed at the Nix store instead of /lib/firmware (sandbox)
#   - CONFIG_LOCALVERSION cleared so the module directory is just '6.15.4'
# The GPU firmware is NOT part of this: the Linux payload dumps it from Orbis on every
# boot and puts it into the initramfs (see _boot.nix). Nothing proprietary in this repo.
# Everything here is built from 'ps4pkgs' (frozen nixpkgs, see host.nix), so the
# kernel only gets rebuilt when that pin or the kernel commit changes.
# If the build fails with a newer GCC after bumping the pin, try clang like upstream does:
#   stdenv = ps4pkgs.llvmPackages_18.stdenv;  extraMakeFlags = [ "LLVM=1" ];

let
  # WiFi/Bluetooth firmware the config builds into the kernel (CONFIG_EXTRA_FIRMWARE).
  # MediaTek blobs come with the kernel repo, Marvell/MediaTek mainline ones from linux-firmware.
  builtinFirmware = ps4pkgs.runCommand "ps4-builtin-firmware" { } ''
    mkdir -p $out/mrvl $out/mediatek
    cp ${ps4-kernel-aeolia-belize}/extra_firmware/* $out/
    cp -L ${ps4pkgs.linux-firmware}/lib/firmware/mrvl/sd8897_uapsta.bin $out/mrvl/
    cp -L ${ps4pkgs.linux-firmware}/lib/firmware/mediatek/mt7668pr2h.bin $out/mediatek/
  '';

  kernelConfig = ps4pkgs.runCommand "ps4-kernel-config" { } ''
    sed \
      -e 's|^CONFIG_EXTRA_FIRMWARE_DIR=.*|CONFIG_EXTRA_FIRMWARE_DIR="${builtinFirmware}"|' \
      -e 's|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=""|' \
      -e 's|^CONFIG_LOCALVERSION_AUTO=y|# CONFIG_LOCALVERSION_AUTO is not set|' \
      ${ps4-kernel-aeolia-belize}/config > $out
    grep -q '^CONFIG_X86_PS4=y' $out
  '';

  kernel = ps4pkgs.linuxManualConfig {
    version = "6.15.4";
    modDirVersion = "6.15.4";
    src = ps4-kernel-aeolia-belize;
    configfile = kernelConfig;
    allowImportFromDerivation = true;
    features.ia32Emulation = true; # CONFIG_IA32_EMULATION=y; needed for hardware.graphics.enable32Bit
  };
in

{
  boot.kernelPackages = ps4pkgs.linuxPackagesFor kernel;

  # for debugging: nix build .#nixosConfigurations.fatty.config.system.build.ps4KernelConfig
  system.build = {
    ps4KernelConfig = kernelConfig;
    ps4BuiltinFirmware = builtinFirmware;
  };
}
