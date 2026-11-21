
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./_partitions.nix
  ];

  boot.loader.grub.device = "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S3Z9NB0KA08224V";


  assertions = [
    {
      assertion = config.boot.kernelPackages.kernel.isLTS;
      message = "wheatley: [MANUAL ASSERTION in hosts/hp-z600-rev2/host.nix] the NVIDIA 580 legacy driver only builds reliably against LTS kernels!";
    }
  ];


  ### NVIDIA GTX 1070 Ti ###
  # Pascal only gets the 580 legacy branch (LTSB, supported until Aug 2028).
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    branch = "legacy_580";
    modesetting.enable = true;
    open = false;
    powerManagement.enable = true;
  };

  boot = {
    initrd.kernelModules = [
      "nvidia"
      "nvidia-drm"
      "nvidia-uvm"
      "nvidia-modeset"
    ];
  };
  ### NVIDIA (end) ###

  nix = {
    settings = {
      max-jobs = 4;
      cores = 2;
    };
  };
}
