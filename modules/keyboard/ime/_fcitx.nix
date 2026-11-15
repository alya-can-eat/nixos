
{ config, pkgs, lib, ... }:


{
  i18n = {
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-mozc
          fcitx5-gtk
          fcitx5-rose-pine
          qt6Packages.fcitx5-chinese-addons
          qt6Packages.fcitx5-configtool
        ];
      };
    };
  };

  environment.variables = {
    QT_IM_MODULE = "fcitx";          # Qt5 und Qt < 6.8.2
    QT_IM_MODULES = "wayland;fcitx"; # Qt >= 6.8.2: zuerst text-input-v3, sonst Fallback
  };
}
