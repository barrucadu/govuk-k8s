{ config, options, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/amazon-image.nix>
  ];

  options = {
    govuk-k8s = {
      externalDomainName = lib.mkOption { default = "govuk-k8s.barrucadu.co.uk"; };
      enableHTTPS = lib.mkOption { default = false; };
      forceHTTPS  = lib.mkOption { default = false; };
    };
  };

  config = {
    ec2.hvm = true;

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
