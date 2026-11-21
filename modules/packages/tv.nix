{ config, pkgs, lib, ... }:

### THIS FILE IS ENTIRELY VIBECODED!!! I just wanna game pls xD ###

### TV APPS ###
# Couch apps that work with a controller: browser for streaming sites, YouTube, Kodi.
# Kodi plays DVDs (with menus), audio CDs and Blu-rays from the optical drive.
# The entries are added once in Steam as non-Steam games ("Add a Non-Steam Game"), they also show up in app launchers.

let
  # apps started from Steam inherit the library path of the Steam runtime, which can break Nix-built apps
  tv-run = pkgs.writeShellScriptBin "tv-run" ''
    unset LD_LIBRARY_PATH
    exec "$@"
  '';

  kodi = pkgs.kodi.withPackages (kodiPkgs: with kodiPkgs; [
    joystick # controller support
    inputstream-adaptive # needed by streaming add-ons (YouTube, Mediatheken, ...)
  ]);

  mkEntry = { name, desktopName, exec, icon, comment }: pkgs.makeDesktopItem {
    inherit name desktopName exec icon comment;
    categories = [ "AudioVideo" ];
  };

  entries = [
    (mkEntry {
      name = "tv-browser";
      desktopName = "TV: Browser";
      exec = "${tv-run}/bin/tv-run /run/current-system/sw/bin/firefox";
      icon = "firefox";
      comment = "Firefox for streaming sites";
    })
    (mkEntry {
      name = "tv-youtube";
      desktopName = "TV: YouTube";
      exec = "${tv-run}/bin/tv-run ${lib.getExe pkgs.vacuum-tube}";
      icon = "rocks.shy.VacuumTube";
      comment = "YouTube TV interface with controller support";
    })
    (mkEntry {
      name = "tv-kodi";
      desktopName = "TV: Kodi (DVD, CD, Blu-ray)";
      exec = "${tv-run}/bin/tv-run ${kodi}/bin/kodi";
      icon = "kodi";
      comment = "Media center for the optical drive and local media";
    })
  ];
in

{
  programs.firefox.policies = {
    EncryptedMediaExtensions.Enabled = true; # Widevine for Netflix, Disney+, ...
  };

  services.udisks2.enable = true; # Kodi uses it to detect inserted discs

  environment = {
    systemPackages = [
      kodi
      pkgs.vacuum-tube
      tv-run
    ] ++ entries;

    # Blu-ray: libbluray loads these at runtime, no rebuild of Kodi or VLC needed
    # (decryption keys still have to be placed in ~/.config/aacs/KEYDB.cfg)
    sessionVariables = {
      LIBAACS_PATH = "${pkgs.libaacs}/lib/libaacs";
      LIBBDPLUS_PATH = "${pkgs.libbdplus}/lib/libbdplus";
    };
  };
}
