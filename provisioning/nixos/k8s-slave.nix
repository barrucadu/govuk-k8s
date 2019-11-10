{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes = {
    kubelet.extraOpts = "--cloud-provider=aws";
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["node"];

    # needed to provision EBS storage
    path = [ pkgs.e2fsprogs ];
  };

  virtualisation.docker.extraOptions = "--insecure-registry=registry.govuk-k8s.test:5000";
}
