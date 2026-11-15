
{ config, pkgs, lib, ps4pkgs, ... }:

### Mesa with PS4 GPU support (Liverpool, Pro: Gladius) ###
# Upstream Mesa doesn't know the PS4 GPU, so radeonsi/radv would refuse it.
# Only the driver package is patched, so nothing else has to be rebuilt.
# The libdrm patch from the community only adds names to amdgpu.ids, so it is skipped.
# Mesa comes from 'ps4pkgs' (frozen nixpkgs, see host.nix), so the patch keeps applying.
# After bumping that pin, refresh the patch if needed from
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
    package = patchMesa ps4pkgs.mesa;
    package32 = patchMesa ps4pkgs.pkgsi686Linux.mesa; # modules/hardware.nix enables 32-bit graphics
  };
}
