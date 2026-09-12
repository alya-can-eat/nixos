{ config, pkgs, lib, ... }:


{  
  home = {
    packages = with pkgs; [
      libprojectm
      projectm-sdl-cpp
    ];

    file = {
      ".local/opt/projectM" = {
        source = ./homefiles/.local/opt/projectM;
        recursive = true;
      };
      ".local/share/projectM" = {
        source = ./homefiles/.local/share/projectM;
        recursive = true;
      };
    };
  };
}
