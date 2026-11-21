{ config, pkgs, lib, ... }:

### THIS FILE IS ENTIRELY VIBECODED!!! I just wanna game pls xD ###

### LIVING ROOM PC ###
# Boots into Steam Big Picture (gamescope session), everything works with a controller.
# Browser, YouTube and Kodi (DVD, audio CD, Blu-ray) are added once in Steam as non-Steam games.
# niri stays installed as "desktop mode" for keyboard and mouse.
#
# Switching sessions:
#   Steam -> niri:  start "Desktop Mode" from the Steam library
#   niri  -> Steam: start "Gaming Mode" from fuzzel (or just reboot)
# session-switch tells AccountsService which session GDM should log into next and ends the current one.
# GDM logs in again after autoLogin.delay seconds. Every boot starts in Steam again (GDM resets it on start).

let
  steam = config.programs.steam.package;
  niri = config.programs.niri.package;

  # apps started from Steam inherit the library path of the Steam runtime, which can break Nix-built apps
  tv-run = pkgs.writeShellScriptBin "tv-run" ''
    unset LD_LIBRARY_PATH
    exec "$@"
  '';

  kodi = pkgs.kodi.withPackages (kodiPkgs: with kodiPkgs; [
    joystick # controller support
    inputstream-adaptive # needed by streaming add-ons (YouTube, Mediatheken, ...)
  ]);

  # entries show up in Steam under "Add a Non-Steam Game"
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
    (mkEntry {
      name = "tv-poweroff";
      desktopName = "Shut Down";
      exec = "${pkgs.systemd}/bin/systemctl poweroff";
      icon = "system-shutdown";
      comment = "Shut down the PC";
    })
    (mkEntry {
      name = "tv-reboot";
      desktopName = "Restart";
      exec = "${pkgs.systemd}/bin/systemctl reboot";
      icon = "system-reboot";
      comment = "Restart the PC";
    })
  ];
in

{
  programs = {
    steam.gamescopeSession = {
      enable = true; # adds the "steam" Wayland session (gamescope + Steam with -tenfoot)
      args = [ "--force-composition" ]; # Fix mause hiding blackscreen
    };
    firefox.policies = {
      EncryptedMediaExtensions.Enabled = true; # Widevine for Netflix, Disney+, ...
    };
  };

  services = {
    displayManager = {
      defaultSession = lib.mkForce "steam"; # niri.nix sets "niri"
      gdm = {
        autoLogin.delay = 2; # timed login: GDM logs in again after a session switch, not only once per boot
        settings.daemon = {
          AutomaticLoginEnable = true;
          AutomaticLogin = config.services.displayManager.autoLogin.user;
        };
      };
    };
    udisks2.enable = true; # Kodi uses it to detect inserted discs
  };

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
