
{ config, pkgs, lib, ... }:


{
  imports = [
    ./keyboard.ime/_fcitx.nix
  ];

  ### keymap ###
  console = {
    keyMap = "sg";
  };
  services.xserver.xkb = {
    layout = "ch";
    variant = "";
  };
}
