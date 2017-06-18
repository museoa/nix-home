{ stdenv, pkgs }:

let
  mkHome = { user, files, environment ? {} }: let
  writeFiles = ./../writeFiles.py;
    src = pkgs.writeText "${user}-nix-home.json" (builtins.toJSON {
       inherit files;
    });
    in stdenv.mkDerivation {
      name = "${user}-nix-home";
      inherit src;
      inherit environment;

      builder = pkgs.writeText "builder.sh" ''
        #!/bin/sh

        . $stdenv/setup

        mkdir -p $out
        ${pkgs.python}/bin/python ${writeFiles} "$src" "$out"
      '';
  };
in
{
  inherit mkHome;
}
