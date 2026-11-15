
{ config, pkgs, lib, ... }:

### Mesa with PS4 GPU support (Liverpool, Pro: Gladius) ###
# Upstream Mesa doesn't know the PS4 GPU, so radeonsi/radv would refuse it.
# Only the driver package is patched, so nothing else has to be rebuilt.
# The libdrm patch from the community only adds names to amdgpu.ids, so it is skipped.
# If a patch stops applying after a nixpkgs update, refresh it from
# https://github.com/DionKill/ps4-video-archlinux (mesa-ps4/).

let
  ps4Patches = [
    ./patches/mesa-ps4.patch
    # Rendering fix written against Mesa main (26.2). Try it once nixpkgs has that version:
    # ./patches/mesa-ps4-vertex-fetch.patch
  ];

  patchMesa = mesa: mesa.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ ps4Patches;
  });
in

{
  hardware.graphics = {
    package = patchMesa pkgs.mesa;
    package32 = patchMesa pkgs.pkgsi686Linux.mesa; # modules/hardware.nix enables 32-bit graphics
  };
}
