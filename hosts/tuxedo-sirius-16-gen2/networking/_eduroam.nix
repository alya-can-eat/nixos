
{ config, pkgs, lib, ... }:


{
  networking = {
    nameservers = lib.mkForce [ ]; # let eduroam use it's own DNS.
    networkmanager = {
      dns = lib.mkForce "default"; # let NM manage resolv.conf normally to not fuck with eduroam DNS
      ensureProfiles.profiles = {
        eduroam = {
          connection = {
            id = "eduroam";
            type = "wifi";
            autoconnect = false;
          };
          wifi = {
            ssid = "eduroam";
            mode = "infrastructure";
          };
          wifi-security = {
            key-mgmt = "wpa-eap";
          };
          "802-1x" = {
            eap = "peap";
            phase2-auth = "mschapv2";
            ca-cert = "/etc/ssl/certs/ca-bundle.crt";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };
  };

}
