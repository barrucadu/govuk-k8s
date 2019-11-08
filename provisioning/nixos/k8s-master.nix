{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  networking.hostName = "k8s-master.govuk-k8s.test";

  services.kubernetes = {
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["master"];
  };

  environment.systemPackages = [
    pkgs.kubectl
  ];
}
