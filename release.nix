{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, officialRelease ? false
, dydisnix_avahi ? {outPath = ./.; rev = 1234;}
, dysnomiaJobset ? import ../dysnomia/release.nix { inherit nixpkgs systems officialRelease; }
, disnixJobset ? import ../disnix/release.nix { inherit nixpkgs systems officialRelease; }
}:

let
  pkgs = import nixpkgs {};
  
  jobs = rec {
    tarball =
      pkgs.releaseTools.sourceTarball {
        name = "dydisnix-avahi-tarball";
        version = builtins.readFile ./version;
        src = dydisnix_avahi;
        inherit officialRelease;
        buildInputs = [ pkgs.pkgconfig pkgs.avahi ];
      };

    build = pkgs.lib.genAttrs systems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      pkgs.releaseTools.nixBuild {
        name = "dydisnix-avahi";
        src = tarball;
        buildInputs = [ pkgs.pkgconfig pkgs.avahi ];
      });
    
    tests = 
      let
        dysnomia = builtins.getAttr (builtins.currentSystem) (dysnomiaJobset.build);
        disnix = builtins.getAttr (builtins.currentSystem) (disnixJobset.build);
        dydisnix_avahi = builtins.getAttr (builtins.currentSystem) build;
      in
      with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
      
      simpleTest {
        nodes = {
          machine =
            {config, pkgs, ...}:
            
            {
              services.openssh.enable = true;
              services.avahi.enable = true;
              services.avahi.publish.enable = true;
              services.avahi.publish.addresses = true;
              services.avahi.publish.domain = true;
              services.avahi.publish.userServices = true;
              virtualisation.writableStore = true;
              
              ids.gids = { disnix = 200; };
              users.extraGroups = [ { gid = 200; name = "disnix"; } ];
              
              services.dbus.enable = true;
              services.dbus.packages = [ disnix ];
  
              systemd.services.disnix =
                { description = "Disnix server";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "dbus.service" ];
                  
                  path = [ pkgs.nix pkgs.getopt disnix dysnomia ];
                  environment = {
                    HOME = "/root";
                  };
                  
                  serviceConfig.ExecStart = "${disnix}/bin/disnix-service";
                };
            
              systemd.services.dydisnix-publishinfra-avahi =
                { description = "DyDisnix Avahi publisher";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "disnix.service" ];
                  requires = [ "avahi-daemon.service" ];
                  
                  path = [ dydisnix_avahi dysnomia "/run/current-system/sw" ];
                  serviceConfig.ExecStart = "${dydisnix_avahi}/bin/dydisnix-publishinfra-avahi";
                };
            
              environment.etc."dysnomia/properties".text = ''
                hostname="$(hostname)"
                mem="$(grep 'MemTotal:' /proc/meminfo | sed -e 's/kB//' -e 's/MemTotal://' -e 's/ //g')"
              '';
              
              environment.systemPackages = [
                dydisnix_avahi pkgs.stdenv
                pkgs.busybox pkgs.paxctl pkgs.gnumake pkgs.patchelf pkgs.gcc pkgs.perlPackages.ArchiveCpio # Required to build something in the VM
              ];
            };
        };
        testScript = ''
          startAll;
          $machine->waitForJob("dydisnix-publishinfra-avahi.service");
          $machine->mustSucceed("sleep 10");
          $machine->mustSucceed("dydisnix-geninfra-avahi > infrastructure.nix");
          $machine->mustSucceed("[ \"\$(grep \"properties.mem=\" infrastructure.nix)\" != \"\" ]");
        '';
      };
  };
in jobs
