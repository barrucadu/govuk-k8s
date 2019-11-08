{
  imports = [ <nixpkgs/nixos/modules/virtualisation/amazon-image.nix> ];
  ec2.hvm = true;

  # we have security groups
  networking.firewall.enable = false;

  # only keep the last 1GiB of systemd journal
  services.journald.extraConfig = "SystemMaxUse=1G";

  # collect nix store garbage and optimise daily
  nix.gc.automatic = true;
  nix.optimise.automatic = true;
}
