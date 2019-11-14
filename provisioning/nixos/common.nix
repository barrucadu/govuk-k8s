{ config, options, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/amazon-image.nix>
    ./vars.nix
  ];

  # These are filled in by the generated vars.nix
  options = {
    govuk-k8s = {
      externalDomainName          = lib.mkOption {};
      enableHTTPS                 = lib.mkOption {};
      forceHTTPS                  = lib.mkOption {};
      concourseGithubUser         = lib.mkOption {};
      concourseGithubClientId     = lib.mkOption {};
      concourseGithubClientSecret = lib.mkOption {};
    };
  };

  config = {
    ec2.hvm = true;

    # this is replaced with the EC2 hostname
    networking.hostName = import /etc/nixos/generated-hostname.nix;

    # we have security groups
    networking.firewall.enable = false;

    # only keep the last 1GiB of systemd journal
    services.journald.extraConfig = "SystemMaxUse=1G";

    # collect nix store garbage and optimise daily
    nix.gc.automatic = true;
    nix.optimise.automatic = true;

    # k8s config shared between master and slaves
    services.kubernetes = {
      apiserver.allowPrivileged = true;
      apiserver.extraOpts = "--cloud-provider=aws";
      apiserver.serviceClusterIpRange = "10.2.0.0/16";
      clusterCidr = "10.1.0.0/16";
      controllerManager.extraOpts = "--cloud-provider=aws";
      masterAddress = "k8s-master.govuk-k8s.test";
    };

    # docker config shared between ci and slaves
    virtualisation.docker = {
      autoPrune.enable = true;
      extraOptions = "--insecure-registry=registry.govuk-k8s.test:5000";
    };
  };
}
