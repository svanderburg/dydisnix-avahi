{config, lib, ...}:

with lib;

let
  cfg = config.services.dydisnixAvahiTest;
in
{
  options = {
    services = {
      dydisnixAvahiTest = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable the Dynamic Disnix Avahi publisher";
        };
        
        package = mkOption {
          type = types.path;
          description = "The Dynamic Disnix Avahi package";
        };
        
        dysnomia = mkOption {
          type = types.path;
          description = "The Dysnomia package";
        };
      };
    };
  };
  
  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        userServices = true;
      };
    };
    
    systemd.services.dydisnix-publishinfra-avahi =
      { description = "DyDisnix Avahi publisher";
        wantedBy = [ "multi-user.target" ];
        after = [ "disnix.service" ];
        requires = [ "avahi-daemon.service" ];
        
        path = [ cfg.package cfg.dysnomia "/run/current-system/sw" ];
        serviceConfig.ExecStart = "${cfg.package}/bin/dydisnix-publishinfra-avahi";
      };
    
    environment.systemPackages = [ cfg.package ];
    
    services.dydisnixAvahiTest.package = mkDefault (import ./release.nix {}).build."${builtins.currentSystem}";
  };
}
