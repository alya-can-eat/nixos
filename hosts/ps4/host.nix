
{ config, pkgs, lib, nixpkgs-ps4, ... }:

### PlayStation 4 CUH-1116A (phat, Aeolia southbridge, firmware 11.52) ###
# Boots from a USB SSD through the PS4 Linux payload (kexec), no GRUB.
# Install from the PC with 'install/partition_ps4.bash', then deploy from the PC:
#   nixos-rebuild switch --flake .#fatty --target-host alya@fatty --sudo --ask-sudo-password
# A local 'glados-rebuild-switch' on the PS4 works too, but if the kernel or Mesa ever
# has to be rebuilt, that happens on the Jaguar CPU and takes hours.
#
### Frozen kernel and Mesa ###
# The kernel and the patched Mesa are built from 'ps4pkgs' (flake input 'nixpkgs-ps4',
# pinned to a commit) instead of the normal nixpkgs. Everything else on fatty updates
# as usual. This way:
#   - the patches can't break when nixpkgs moves on (e.g. the switch to 26.11)
#   - a flake update doesn't rebuild the kernel and Mesa (they are never in the cache)
# Downside: no more fixes for Mesa/LLVM from nixpkgs (the kernel gets none anyway).
# To bump on purpose: change the commit of 'nixpkgs-ps4' in flake.nix, then
#   nix build .#nixosConfigurations.fatty.config.hardware.graphics.package -L
# and rebase hosts/ps4/patches/mesa-ps4.patch if a hunk fails.

{
  imports = [
    ./_kernel.nix
    ./_boot.nix
    ./_graphics.nix
  ];

  _module.args.ps4pkgs = nixpkgs-ps4.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  nix = {
    settings = {
      max-jobs = 2;
      cores = 4;
    };
  };
}
