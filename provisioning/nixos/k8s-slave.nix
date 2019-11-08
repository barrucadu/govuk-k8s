{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  networking.hostName = "k8s-slave.govuk-k8s.test";

  services.kubernetes = {
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["node"];
  };

  environment.systemPackages = [
    pkgs.kubectl
  ];
}
