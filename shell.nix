{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {

  buildInputs = [
    #apt
    #dpkg
    nur.repos.milahu.apt-file
    nur.repos.milahu.apt-init-config
  ];

}
