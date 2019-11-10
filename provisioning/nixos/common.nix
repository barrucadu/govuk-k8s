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
    networking.hostName = "HOSTNAME_PLACEHOLDER";

    # we have security groups
    networking.firewall.enable = false;

    # only keep the last 1GiB of systemd journal
    services.journald.extraConfig = "SystemMaxUse=1G";

    # collect nix store garbage and optimise daily
    nix.gc.automatic = true;
    nix.optimise.automatic = true;
  };
}
