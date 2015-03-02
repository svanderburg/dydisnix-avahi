{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, officialRelease ? false
, dydisnix_avahi ? {outPath = ./.; rev = 1234;}
}:

let
  pkgs = import nixpkgs {};
  
  jobs = rec {
    tarball =
      pkgs.releaseTools.sourceTarball {
        name = "dydisnix-tarball";
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
        name = "dydisnix";
        src = tarball;
        buildInputs = [ pkgs.pkgconfig pkgs.avahi ];
      });
  };
in jobs
