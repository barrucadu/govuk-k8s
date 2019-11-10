#!/bin/sh

SLAVES="$1"

function build_host () {
  host="$1"
  config="${2:-$host}"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/vars.nix"      "${host}.govuk-k8s.test:/etc/nixos/vars.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/common.nix"    "${host}.govuk-k8s.test:/etc/nixos/common.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/${config}.nix" "${host}.govuk-k8s.test:/etc/nixos/configuration.nix"
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${host}.govuk-k8s.test" <<EOF
sed -i "s/HOSTNAME_PLACEHOLDER/\$(curl http://169.254.169.254/latest/meta-data/hostname)/g" /etc/nixos/common.nix
if ! nixos-rebuild switch; then
   echo "trying again in 20 seconds in case it was just the usual culprit (etcd / kubernetes race condition)"
   sleep 20
   nixos-rebuild switch
fi
EOF
}

set -ex

for i in $(seq 0 "$((SLAVES - 1))"); do
  build_host "k8s-slave-${i}" k8s-slave
done

build_host k8s-master
build_host ci
build_host registry
build_host web
build_host jumpbox
