{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {

  buildInputs = [
    #apt
    #dpkg
    # https://github.com/milahu/nur-packages/tree/master/pkgs/tools/package-management/apt-file
    nur.repos.milahu.apt-file
    # https://github.com/milahu/nur-packages/tree/master/pkgs/tools/package-management/apt-init-config
    nur.repos.milahu.apt-init-config
  ];

}
