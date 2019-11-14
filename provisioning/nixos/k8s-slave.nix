{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  services.kubernetes.roles = ["node"];
  # needed to provision EBS storage
  services.kubernetes.path = [ pkgs.e2fsprogs ];
}
