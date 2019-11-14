{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes.roles = ["master"];

  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];
}
