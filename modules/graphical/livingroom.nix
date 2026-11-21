{ config, pkgs, lib, ... }:

### THIS FILE IS ENTIRELY VIBECODED!!! I just wanna game pls xD ###

### LIVING ROOM PC ###
# Boots into Steam Big Picture (gamescope session), everything works with a controller.
# Browser, YouTube and Kodi (DVD, audio CD, Blu-ray) are added once in Steam as non-Steam games.
# niri stays installed as "desktop mode" for keyboard and mouse.
#
# Switching sessions:
#   Steam -> niri:  power menu -> "Switch to Desktop"
#   niri  -> Steam: start "Gaming Mode" from fuzzel (or just reboot)
# session-switch tells AccountsService which session GDM should log into next and ends the current one.
# GDM logs in again after autoLogin.delay seconds. Every boot starts in Steam again (GDM resets it on start).

let
  niri = config.programs.niri.package;

  # quits Steam (gamescope and the session end with it), ends the session after 15 s if Steam hangs
  # usage: steam-quit SESSION_ID
  steam-quit = pkgs.writeShellApplication {
    name = "steam-quit";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      session_id="''${1:-}"
      # system path instead of the store path: this script ends up inside Steam's own environment
      # (steam-session-select), a store reference to Steam would be a dependency loop
      /run/current-system/sw/bin/steam -shutdown || true
      sleep 15
      if [ -n "$session_id" ]; then
        loginctl terminate-session "$session_id" || true # fails harmlessly if the session is already gone
      fi
    '';
  };

  # usage: session-switch steam|niri
  session-switch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
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
          # run steam-quit as a separate systemd user unit, outside of Steam's process tree:
          # Steam counts everything started by a shortcut as still running (its reaper waits for all child processes),
          # so it would not quit while the caller is still "running"
          systemd-run --user --collect --quiet ${steam-quit}/bin/steam-quit "''${XDG_SESSION_ID:-}"
          ;;
        steam)
          ${niri}/bin/niri msg action quit --skip-confirmation
          ;;
      esac
    '';
  };

  # Steam's own "Switch to Desktop" (power menu) calls this SteamOS script and waits until Steam gets ended
  # newer clients call holo-session-select, older ones steamos-session-select (argument: plasma, gamescope, ...)
  steam-session-select =
    let
      script = pkgs.writeShellApplication {
        name = "steamos-session-select";
        text = ''
          session="''${1:-gamescope}"
          case "$session" in
            gamescope) echo "steamos-session-select: already in Steam" >&2 ;;
            *) exec ${session-switch}/bin/session-switch niri ;;
          esac
        '';
      };
    in
    pkgs.runCommand "steam-session-select" { } ''
      mkdir -p $out/bin
      ln -s ${script}/bin/steamos-session-select $out/bin/steamos-session-select
      ln -s ${script}/bin/steamos-session-select $out/bin/holo-session-select
    '';

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
    steam = {
      gamescopeSession = {
        enable = true; # adds the "steam" Wayland session (gamescope + Steam with -tenfoot)
        args = [ "--force-composition" ]; # Fix mouse hiding blackscreen (Steam turns it off again, see force-composition.lua below)
      };
      extraPackages = [ steam-session-select ]; # inside Steam's FHS environment, where Steam looks for it
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
        # GDM 50 refuses the timed login unless automatic login is enabled as well,
        # but NixOS only writes TimedLogin* when the delay is > 0, so add AutomaticLogin* by hand.
        # Result: boot logs in right away (once per boot), after a session switch the timed login takes over.
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

    # GTX 10 (Pascal): direct scan-out shows a black screen, so composition has to stay on.
    # Steam turns composite_force off after it starts (overriding --force-composition),
    # this gamescope script turns it back on after every frame where it is off.
    etc."gamescope/scripts/force-composition.lua" = {
      mode = "0444"; # real file instead of a symlink, gamescope only loads regular files
      text = ''
        gamescope.hook("OnPostPaint", function()
            if not gamescope.convars.composite_force.value then
                gamescope.convars.composite_force.value = true
                gamescope.log(gamescope.log_priority.info, "force-composition.lua: composite_force was turned off, turned it back on")
            end
        end)
      '';
    };
  };
}
