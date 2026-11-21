
{ config, pkgs, lib, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages;
  };
}
