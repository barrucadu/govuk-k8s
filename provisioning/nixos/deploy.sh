#!/usr/bin/env bash

function build_host () {
  host="$1"
  config="${2:-$host}"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/vars.nix"      "${host}.govuk-k8s.test:/etc/nixos/vars.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/common.nix"    "${host}.govuk-k8s.test:/etc/nixos/common.nix"
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "nixos/${config}.nix" "${host}.govuk-k8s.test:/etc/nixos/configuration.nix"
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${host}.govuk-k8s.test" <<EOF
set -ex
[[ ! -e /etc/nixos/generated-hostname.nix ]] && curl http://169.254.169.254/latest/meta-data/hostname | sed 's:^:":' | sed 's:$:":' > /etc/nixos/generated-hostname.nix
nixos-rebuild switch
EOF
}

set -ex

build_host ci
build_host registry
build_host web
build_host jumpbox
