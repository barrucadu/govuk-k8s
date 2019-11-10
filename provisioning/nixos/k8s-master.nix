{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes = {
    apiserver.allowPrivileged = true;
    apiserver.extraOpts = "--cloud-provider=aws";
    controllerManager.extraOpts = "--cloud-provider=aws";
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["master"];
  };

  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];
}
