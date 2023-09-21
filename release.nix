{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, officialRelease ? false
, dydisnix_avahi ? { outPath = ./.; rev = 1234; }
, dysnomia ? { outPath = ../dysnomia; rev = 1234; }
, disnix ? { outPath = ../disnix; rev = 1234; }
}:

let
  pkgs = import nixpkgs {};

  dysnomiaJobset = import "${dysnomia}/release.nix" {
    inherit nixpkgs systems officialRelease dysnomia;
  };

  disnixJobset = import "${disnix}/release.nix" {
    inherit nixpkgs systems officialRelease dysnomia disnix;
  };

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
      with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

      simpleTest {
        name = "tests";
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
              users.extraGroups = {
                disnix = { gid = 200; };
              };

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
              ];
            };
        };
        testScript = ''
          start_all()

          machine.wait_for_unit("dydisnix-publishinfra-avahi.service")
          machine.succeed("sleep 10")
          machine.succeed("dydisnix-geninfra-avahi > infrastructure.nix")

          # Check if the output of the generated expression matches some things we expect
          machine.succeed('[ "$(grep "  \\"machine\\" = {" infrastructure.nix)" != "" ]')
          machine.succeed('[ "$(grep "    properties.\\"mem\\"=" infrastructure.nix)" != "" ]')
          machine.succeed(
              '[ "$(grep "    properties.\\"supportedTypes\\"=\\[ \\"process\\"" infrastructure.nix)" != "" ]'
          )
        '';
      };
  };
in jobs
