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

  # usage: session-switch steam|niri
  session-switch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      util-linux
    ];
    text = ''
      target="''${1:-}"
      case "$target" in
        steam|niri) ;;
        *)
          echo "usage: session-switch steam|niri" >&2
          exit 1
          ;;
      esac

      # same calls as the set-session script of the NixOS GDM module, but only for the current user
      user_path="/org/freedesktop/Accounts/User$(id -u)"
      busctl --system call org.freedesktop.Accounts "$user_path" org.freedesktop.Accounts.User SetSession s "$target"
      busctl --system call org.freedesktop.Accounts "$user_path" org.freedesktop.Accounts.User SetSessionType s wayland

      case "$target" in
        niri)
          # quitting Steam also ends gamescope and with it the session
          # fallback: end the session after 30 s if Steam does not quit (e.g. stuck cloud sync)
          session_id="''${XDG_SESSION_ID:-}"
          setsid -f sh -c "${steam}/bin/steam -shutdown; sleep 30; [ -n '$session_id' ] && loginctl terminate-session '$session_id'" >/dev/null 2>&1
          ;;
        steam)
          ${niri}/bin/niri msg action quit --skip-confirmation
          ;;
      esac
    '';
  };

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
      name = "session-desktop";
      desktopName = "Desktop Mode";
      exec = "${session-switch}/bin/session-switch niri";
      icon = "computer";
      comment = "Switch to niri";
    })
    (mkEntry {
      name = "session-gaming";
      desktopName = "Gaming Mode";
      exec = "${session-switch}/bin/session-switch steam";
      icon = "steam";
      comment = "Switch to Steam Big Picture";
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
      session-switch
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
