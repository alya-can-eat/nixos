
{ config, pkgs, lib, ... }:

### PlayStation 4 CUH-1116A (phat, Aeolia southbridge, firmware 11.52) ###
# Boots from a USB SSD through the PS4 Linux payload (kexec), no GRUB.
# Install from the PC with 'install/partition_ps4.bash', then deploy from the PC:
#   nixos-rebuild switch --flake .#fatty --target-host alya@fatty --sudo --ask-sudo-password
# A local 'glados-rebuild-switch' on the PS4 works too, but after a flake update it
# compiles the kernel and Mesa on the Jaguar CPU, which takes hours.

{
  imports = [
    ./_kernel.nix
    ./_boot.nix
    ./_graphics.nix
  ];

  nix = {
    settings = {
      max-jobs = 2;
      cores = 4;
    };
  };
}
