{
  description = "We do what we must because we can";


  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-26.05";
#      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };

    ### home-manager ###
    home-manager = {
      url = github:nix-community/home-manager/release-26.05; # stable channel
#      url = github:nix-community/home-manager/; # unstable channel
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### declarative-flatpak ###
    declarative-flatpak = {
      url = "github:in-a-dil-emma/declarative-flatpak/latest";
    };

    ### impermanence ###
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    ### wl_shimeji ###
    wl_shimeji = {
      url = "git+https://github.com/CluelessCatBurger/wl_shimeji?submodules=1";
#      url = "path:./users/alya/home-manager/homefiles/.local/opt/wl_shimeji";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  ### PS4 kernel (Aeolia/Belize; Baikal needs another branch) ###
  ps4-kernel-aeolia-belize = {
    url = "github:feeRnt/ps4-linux-12xx/6.15.4-aeolia-belize-crashniels";
    flake = false;
  };

  outputs = { self, nixpkgs, ... } @attrs: 

  let
    mkHost = { system, hostModules}: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = attrs;
      modules = [
        ./modules/fonts.nix
        ./modules/keyboard.nix
        ./modules/datetime.nix
        ./modules/services.nix
        ./modules/networking.nix
        ./users/alya/user.nix
        ./modules/nix.nix
        ./modules/locales.nix
        ./modules/boot.nix
        ./modules/packages.nix
        ./modules/hardware.nix
        ./modules/audio.nix
        ./modules/home-manager.nix
        ./modules/security.nix
      ] ++ hostModules;
    };
  in {
    nixosConfigurations = {
      ### aperture: to build run 'nixos-rebuild switch --flake /etc/nixos#aperture' ###
      aperture = mkHost {
        system = "x86_64-linux";
        hostModules = [
          ./hosts/tuxedo-sirius-16-gen2/host.nix
          ./hosts/tuxedo-sirius-16-gen2/hardware-configuration.nix
          ./modules/boot/kernel/linux_zen.nix
          ./modules/boot/efi.nix
          ./modules/impermanence.nix
          ./modules/graphical/niri.nix
          ./modules/printing.nix
          ./modules/virtualisation.nix
          ./modules/packages/tex.nix
          ./modules/packages/steam.nix
          ./modules/declarative-flatpak.nix
          ./modules/networking/tunnels.nix
          {
            networking.hostName = "aperture";
            system.stateVersion = "25.11";
          }
        ];
      };
      wheatley = mkHost {
        system = "x86_64-linux";
        hostModules = [
          ./hosts/hp-z600-rev2/host.nix
          ./hosts/hp-z600-rev2/hardware-configuration.nix
          ./modules/boot/kernel/linux_zen.nix
          ./modules/boot/bios.nix
          ./modules/impermanence.nix
          ./modules/graphical/niri.nix
          ./modules/packages/steam.nix
          ./modules/declarative-flatpak.nix
          ./modules/networking/tunnels.nix
          {
            networking.hostName = "wheatley";
            system.stateVersion = "26.05";
          }
        ];
      };
      caroline = mkHost {
        system = "x86_64-linux";
        hostModules = [
          ./hosts/serverpc/host.nix
          ./hosts/serverpc/hardware-configuration.nix
          ./modules/boot/kernel/linux_latest_zfs.nix
          ./modules/zfs.nix
          ./modules/boot/efi.nix
          ./modules/impermanence.nix
          ./modules/graphical/niri.nix
          ./modules/printing.nix
          ./modules/virtualisation.nix
          # ./modules/packages/tex.nix
          # ./modules/packages/steam.nix
          ./modules/declarative-flatpak.nix
          {
            networking.hostName = "caroline";
            system.stateVersion = "26.05";
          }
        ];
      };
      ### fatty (PS4): install from the PC with 'install/partition_ps4.bash', see hosts/ps4/host.nix ###
      fatty = mkHost {
        system = "x86_64-linux";
        hostModules = [
          ./hosts/ps4/host.nix
          ./hosts/ps4/hardware-configuration.nix
          ./modules/impermanence.nix
          ./modules/graphical/niri.nix
          ./modules/declarative-flatpak.nix
          ./modules/packages/steam.nix
          ./modules/networking/tunnels.nix
          {
            networking.hostName = "fatty";
            system.stateVersion = "26.05";
          }
        ];
      };
    };
  };
}
