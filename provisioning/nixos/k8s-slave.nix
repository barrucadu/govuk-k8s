{
  imports = [ ./common.nix ];

  networking.hostName = "HOSTNAME_PLACEHOLDER.govuk-k8s.test";

  services.kubernetes = {
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["node"];
  };
}
