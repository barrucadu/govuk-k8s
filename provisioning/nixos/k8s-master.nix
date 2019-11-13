{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes = {
    apiserver.allowPrivileged = true;
    apiserver.extraOpts = "--cloud-provider=aws";
    apiserver.serviceClusterIpRange = "10.2.0.0/16";
    clusterCidr = "10.1.0.0/16";
    controllerManager.extraOpts = "--cloud-provider=aws";
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["master"];
  };

  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
  ];
}
