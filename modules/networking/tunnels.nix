
{ config, pkgs, lib, ... }:


{
  systemd = {
    user.services = {
      tunnel_minecraft-tschudibacon = {
        description = "Cloudflared TCP tunnel for Tschudibacon Minecraft";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared access tcp --hostname minecraft.tschudibacon.com --url 127.0.0.72:25565";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      tunnel_minecraft-b173-tschudibacon = {
        description = "Cloudflared TCP tunnel for Tschudibacon Minecraft Beta 1.7.3";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared access tcp --hostname minecraft-b173.tschudibacon.com --url 127.0.0.73:25565";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      tunnel_minecraft-r164-tschudibacon = {
        description = "Cloudflared TCP tunnel for Tschudibacon Minecraft 1.6.4";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared access tcp --hostname minecraft-r164.tschudibacon.com --url 127.0.0.74:25565";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
      tunnel_minecraft-a11201-tschudibacon = {
        description = "Cloudflared TCP tunnel for Tschudibacon Minecraft Alpha 1.1.2_01";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.cloudflared}/bin/cloudflared access tcp --hostname minecraft-a11201.tschudibacon.com --url 127.0.0.75:25565";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };

  networking = {
    hosts = {
      "127.0.0.72" = [ "minecraft.tschudibacon.mc" ];
      "127.0.0.73" = [ "minecraft-b173.tschudibacon.mc" ];
      "127.0.0.74" = [ "minecraft-r164.tschudibacon.mc" ];
      "127.0.0.75" = [ "minecraft-a11201.tschudibacon.mc" ];
    };
  };

}
