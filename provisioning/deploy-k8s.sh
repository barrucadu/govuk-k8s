#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

source "$(git rev-parse --show-toplevel)/config"

config_dir="$(dirname "$KUBECONFIG")"
[[ ! -d "$config_dir" ]] && mkdir -p "$config_dir"

config_map_aws_auth="$(mktemp --suffix='.yaml')"
trap 'rm "$config_map_aws_auth"' EXIT

pushd terraform
HOST="$(terraform output public-ssh-ip)"
terraform output kubeconfig          > "$KUBECONFIG"
terraform output config_map_aws_auth > "$config_map_aws_auth"
popd

kubectl="$(git rev-parse --show-toplevel)/util/kubectl.sh"
"$kubectl" apply -f "$config_map_aws_auth"
"$kubectl" apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
for file in k8s/*.yaml; do
  "$kubectl" apply -f "$file"
done
