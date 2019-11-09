{
  imports = [ ./common.nix ];

  services.kubernetes = {
    masterAddress = "k8s-master.govuk-k8s.test";
    roles = ["node"];
  };
}
