#!/bin/sh

SLAVES="$1"

function build_host () {
  host="$1"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/common.nix"  "${host}.govuk-k8s.test:/etc/nixos/common.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/${host}.nix" "${host}.govuk-k8s.test:/etc/nixos/configuration.nix"
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${host}.govuk-k8s.test" nixos-rebuild switch
}

set -ex

build_host k8s-master

secret=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no k8s-master.govuk-k8s.test cat /var/lib/kubernetes/secrets/apitoken.secret)
for i in $(seq 0 "$((SLAVES - 1))"); do
  slave_host="k8s-slave-${i}"
  cp nixos/k8s-slave.nix "nixos/${slave_host}.nix"
  sed -i "s#HOSTNAME_PLACEHOLDER#${slave_host}#" "nixos/${slave_host}.nix"
  build_host "${slave_host}"
done

build_host web

cp nixos/common.nix  /etc/nixos/common.nix
cp nixos/jumpbox.nix /etc/nixos/configuration.nix
nixos-rebuild switch
