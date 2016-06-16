{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, officialRelease ? false
, dydisnix_avahi ? {outPath = ./.; rev = 1234;}
, fetchDependenciesFromNixpkgs ? false
}:

let
  pkgs = import nixpkgs {};
  
  # Refer either to dysnomia in the parent folder, or to the one in Nixpkgs
  dysnomiaJobset = if fetchDependenciesFromNixpkgs then {
    build = pkgs.lib.genAttrs systems (system:
      (import nixpkgs { inherit system; }).dysnomia
    );
  } else import ../dysnomia/release.nix { inherit nixpkgs systems officialRelease; };
  
  # Refer either to disnix in the parent folder, or to the one in Nixpkgs
  disnixJobset = if fetchDependenciesFromNixpkgs then {
    tarball = pkgs.dysnomia.src;
    
    build = pkgs.lib.genAttrs systems (system:
      (import nixpkgs { inherit system; }).disnix
    );
  } else import ../disnix/release.nix { inherit nixpkgs systems officialRelease; };
  
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
      in
      with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };
      
      simpleTest {
        nodes = {
          machine =
            {config, pkgs, ...}:
            
            {
              imports = [ ./dydisnix-avahi-module.nix ];
              
              services.dydisnixAvahiTest.enable = true;
              services.dydisnixAvahiTest.dysnomia = dysnomia;
              services.dydisnixAvahiTest.package = builtins.getAttr (builtins.currentSystem) build;
              
              services.avahi.interfaces = [ "eth1" ]; # Only bind to one network interface, otherwise the machine appears multiple times in the generated infrastructure model
              
              services.openssh.enable = true;
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
            
              environment.etc."dysnomia/properties".text = ''
                hostname="$(hostname)"
                mem="$(grep 'MemTotal:' /proc/meminfo | sed -e 's/kB//' -e 's/MemTotal://' -e 's/ //g')"
                supportedTypes=("process" "wrapper")
              '';
              
              environment.systemPackages = [
                pkgs.stdenv
                pkgs.busybox pkgs.paxctl pkgs.gnumake pkgs.patchelf pkgs.gcc pkgs.perlPackages.ArchiveCpio # Required to build something in the VM
              ];
            };
        };
        testScript = ''
          startAll;
          $machine->waitForJob("dydisnix-publishinfra-avahi.service");
          $machine->mustSucceed("sleep 10");
          $machine->mustSucceed("dydisnix-geninfra-avahi > infrastructure.nix");
          
          # Check if the output of the generated expression matches some things we expect
          $machine->mustSucceed("[ \"\$(grep \"  \\\"machine\\\" = {\" infrastructure.nix)\" != \"\" ]");
          $machine->mustSucceed("[ \"\$(grep \"    properties.\\\"mem\\\"=\" infrastructure.nix)\" != \"\" ]");
          $machine->mustSucceed("[ \"\$(grep \"    properties.\\\"supportedTypes\\\"=\\[ \\\"process\\\"\" infrastructure.nix)\" != \"\" ]");
        '';
      };
  };
in jobs
