{ stdenv, pkgs, lib }:

let

  writeFiles = ../writeFiles.py;

  mkHome = { user, files }:
    let src = pkgs.writeText "${user}-nix-home.json" (builtins.toJSON {
       inherit files;
    });

    in stdenv.mkDerivation {
      name = "${user}-nix-home";
      inherit src;
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
