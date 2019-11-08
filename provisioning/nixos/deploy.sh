#!/bin/sh

function build_host () {
  host="$1"
  config="$2"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/common.nix"    "${host}.govuk-k8s.test:/etc/nixos/common.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/${config}.nix" "${host}.govuk-k8s.test:/etc/nixos/configuration.nix"
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${host}.govuk-k8s.test" nixos-rebuild switch
}

set -ex

build_host k8s-master k8s-master
build_host k8s-slave  k8s-slave

cp nixos/common.nix  /etc/nixos/common.nix
cp nixos/jumpbox.nix /etc/nixos/configuration.nix
nixos-rebuild switch
