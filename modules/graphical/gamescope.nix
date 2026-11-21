{ config, pkgs, lib, ... }:

### THIS FILE IS ENTIRELY VIBECODED!!! I just wanna game pls xD ###

### GAMESCOPE (Steam Gaming Mode) ###
# Boots into Steam Big Picture in a gamescope session, like SteamOS. Everything works with a controller.
# Needs GDM with autologin (e.g. from niri.nix).
#
# Switching sessions:
#   Steam   -> desktop: power menu -> "Switch to Desktop" (desktop session: gamingMode.desktop, default niri)
#   desktop -> Steam:   start "Gaming Mode" (e.g. from fuzzel), or just reboot
# session-switch tells AccountsService which session GDM should log into next and ends the current one.
# GDM logs in again after autoLogin.delay seconds. Every boot starts in Steam again (GDM resets it on start).

let
  cfg = config.gamingMode;
  autoLogin = config.services.displayManager.autoLogin;

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
      # (steamos-stubs), a store reference to Steam would be a dependency loop
      /run/current-system/sw/bin/steam -shutdown || true
      sleep 15
      if [ -n "$session_id" ]; then
        loginctl terminate-session "$session_id" || true # fails harmlessly if the session is already gone
      fi
    '';
  };

  # usage: session-switch SESSION (steam, or the desktop session)
  session-switch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      target="''${1:-}"
      if [ -z "$target" ]; then
        echo "usage: session-switch SESSION" >&2
        exit 1
      fi

      # same calls as the set-session script of the NixOS GDM module, but only for the current user
      # (session type is always wayland: gamescope and niri are both Wayland sessions)
      user_path="/org/freedesktop/Accounts/User$(id -u)"
      busctl --system call org.freedesktop.Accounts "$user_path" org.freedesktop.Accounts.User SetSession s "$target"
      busctl --system call org.freedesktop.Accounts "$user_path" org.freedesktop.Accounts.User SetSessionType s wayland

      if [ "$target" = "steam" ]; then
        # leaving the desktop
        ${cfg.desktop.quitCommand}
      else
        # leaving Steam: run steam-quit as a separate systemd user unit, outside of Steam's process tree.
        # Steam counts everything started from it as still running (its reaper waits for all child processes),
        # so it would not quit while the caller is still "running"
        systemd-run --user --collect --quiet ${steam-quit}/bin/steam-quit "''${XDG_SESSION_ID:-}"
      fi
    '';
  };

  # With -steamos3, Steam calls these SteamOS helper scripts (inside its FHS environment, so they go into
  # programs.steam.extraPackages). Same names as the stubs of Jovian-NixOS, reduced to what Steam needs here.
  # Newer clients call holo-*, older ones steamos-*.
  steamos-stubs =
    let
      # Steam's own "Switch to Desktop" (power menu) calls this with plasma (or plasma-wayland, ...)
      session-select = pkgs.writeShellApplication {
        name = "steamos-session-select";
        text = ''
          session="''${1:-gamescope}"
          case "$session" in
            gamescope) echo "steamos-session-select: already in Steam" >&2 ;;
            *) ${
              if cfg.desktop.session != null then
                "exec ${session-switch}/bin/session-switch ${lib.escapeShellArg cfg.desktop.session}"
              else
                ''echo "steamos-session-select: no desktop session set (gamingMode.desktop.session)" >&2''
            } ;;
          esac
        '';
      };
      # no SteamOS branches here, pretend to be on "main"
      select-branch = pkgs.writeShellApplication {
        name = "steamos-select-branch";
        text = ''
          case "''${1:-}" in
            -c|-l) echo "main" ;;
            *) ;;
          esac
        '';
      };
      # updates come from nixos-rebuild, 7 = "no update available"
      update = pkgs.writeShellApplication {
        name = "steamos-update";
        text = "exit 7";
      };
      # no Steam Deck BIOS here, 0 = nothing to do
      biosupdate = pkgs.writeShellApplication {
        name = "jupiter-biosupdate";
        text = "exit 0";
      };
      reboot = pkgs.writeShellApplication {
        name = "holo-reboot";
        runtimeInputs = [ pkgs.systemd ];
        text = "exec systemctl reboot";
      };
      # Steam runs the helpers above with pkexec, they need no root here, so just run the command
      # (the real pkexec cannot work inside Steam's sandbox anyway)
      pkexec = pkgs.writeShellApplication {
        name = "pkexec";
        text = ''
          args=()
          for arg in "$@"; do
            [ "$arg" = "--disable-internal-agent" ] || args+=("$arg")
          done
          exec "''${args[@]}"
        '';
      };
    in
    pkgs.runCommand "steamos-stubs" { } ''
      mkdir -p $out/bin/steamos-polkit-helpers
      ln -s ${session-select}/bin/steamos-session-select $out/bin/steamos-session-select
      ln -s ${session-select}/bin/steamos-session-select $out/bin/holo-session-select
      ln -s ${select-branch}/bin/steamos-select-branch $out/bin/steamos-select-branch
      ln -s ${select-branch}/bin/steamos-select-branch $out/bin/holo-select-branch
      ln -s ${update}/bin/steamos-update $out/bin/steamos-update
      ln -s ${update}/bin/steamos-update $out/bin/holo-update
      ln -s ${update}/bin/steamos-update $out/bin/steamos-polkit-helpers/steamos-update
      ln -s ${biosupdate}/bin/jupiter-biosupdate $out/bin/jupiter-biosupdate
      ln -s ${biosupdate}/bin/jupiter-biosupdate $out/bin/steamos-polkit-helpers/jupiter-biosupdate
      ln -s ${reboot}/bin/holo-reboot $out/bin/holo-reboot
      ln -s ${pkexec}/bin/pkexec $out/bin/pkexec
    '';

  # entries show up in Steam under "Add a Non-Steam Game" (and in every app launcher)
  mkEntry = { name, desktopName, exec, icon, comment }: pkgs.makeDesktopItem {
    inherit name desktopName exec icon comment;
  };

  entries = lib.optional (cfg.desktop.session != null) (mkEntry {
    name = "session-gaming";
    desktopName = "Gaming Mode";
    exec = "${session-switch}/bin/session-switch steam";
    icon = "steam";
    comment = "Switch to Steam Big Picture";
  }) ++ [
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
  options.gamingMode.desktop = {
    session = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if config.programs.niri.enable then "niri" else null;
      defaultText = lib.literalExpression ''if config.programs.niri.enable then "niri" else null'';
      description = ''Wayland session that "Switch to Desktop" logs into. null turns desktop switching off.'';
    };
    quitCommand = lib.mkOption {
      type = lib.types.str;
      default = "${config.programs.niri.package}/bin/niri msg action quit --skip-confirmation";
      defaultText = lib.literalExpression ''"''${config.programs.niri.package}/bin/niri msg action quit --skip-confirmation"'';
      description = ''Command that ends the desktop session, used by "Gaming Mode".'';
    };
  };

  config = {
    assertions = [
      {
        assertion = config.services.displayManager.gdm.enable && autoLogin.enable;
        message = "[MANUAL ASSERTION in modules/graphical/gamescope.nix] needs GDM with autologin (e.g. from niri.nix)!";
      }
    ];

    programs.steam = {
      enable = true;
      gamescopeSession = {
        enable = true; # adds the "steam" Wayland session (gamescope + Steam Big Picture)
        # -steamos3: without it, "Switch to Desktop" in the power menu does nothing (Steam never calls
        # steamos-session-select), with it Steam also calls the other SteamOS helpers (steamos-stubs)
        steamArgs = [
          "-steamos3"
          "-gamepadui"
          "-pipewire-dmabuf"
        ];
      };
      extraPackages = [ steamos-stubs ]; # inside Steam's FHS environment, where Steam looks for them
    };

    services.displayManager = {
      defaultSession = lib.mkForce "steam"; # niri.nix sets "niri"
      gdm = {
        autoLogin.delay = 2; # timed login: GDM logs in again after a session switch, not only once per boot
        # GDM 50 refuses the timed login unless automatic login is enabled as well,
        # but NixOS only writes TimedLogin* when the delay is > 0, so add AutomaticLogin* by hand.
        # Result: boot logs in right away (once per boot), after a session switch the timed login takes over.
        settings.daemon = {
          AutomaticLoginEnable = true;
          AutomaticLogin = autoLogin.user;
        };
      };
    };

    environment.systemPackages = [ session-switch ] ++ entries;
  };
}
