{ pkgs, list }:
{
  script =
    # bash
    ''
      for i in ${toString list}; do
        echo "$i" ${pkgs.hello}/bin/hello
      done
      x=${
        pkgs.lib.concatStringsSep " " list
      }
      echo "$x"
    '';
}
