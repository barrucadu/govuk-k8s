{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes = {
    apiserver.allowPrivileged = true;
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["master"];
  };

  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];
}
