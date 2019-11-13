{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes = {
    apiserver.serviceClusterIpRange = "10.2.0.0/16";
    clusterCidr = "10.1.0.0/16";
    kubelet.extraOpts = "--cloud-provider=aws";
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["node"];

    # needed to provision EBS storage
    path = [ pkgs.e2fsprogs ];
  };

  virtualisation.docker.extraOptions = "--insecure-registry=registry.govuk-k8s.test:5000";
}
