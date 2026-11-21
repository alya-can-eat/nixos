{ config, pkgs, lib, ... }:

### THIS FILE IS ENTIRELY VIBECODED!!! I just wanna game pls xD ###

### gamescope on the GTX 1070 Ti (Pascal) ###
# Direct scan-out shows a black screen (as soon as the mouse cursor hides), so composition has to stay on.
# --force-composition covers the start, but Steam turns composite_force off again after it starts,
# so this gamescope script turns it back on after every frame where it is off.
# Only active if the Steam gamescope session is (modules/graphical/gamescope.nix).

let
  # mkIf on each value instead of the whole module: the condition reads programs.steam.gamescopeSession,
  # which this file also adds to (infinite recursion otherwise)
  enabled = config.programs.steam.gamescopeSession.enable;
in

{
  programs.steam.gamescopeSession.args = lib.mkIf enabled [ "--force-composition" ];

  environment.etc."gamescope/scripts/force-composition.lua" = lib.mkIf enabled {
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
}
