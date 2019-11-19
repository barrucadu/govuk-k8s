#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ "$MODE" != "aws" ]]; then
    echo "MODE != aws"
    exit 1
fi

HERE="${TOP}/provisioning/aws"
cd "$HERE"

config_dir="$(dirname "$KUBECONFIG")"
[[ ! -d "$config_dir" ]] && mkdir -p "$config_dir"

config_map_aws_auth="$(mktemp --suffix='.yaml')"
trap 'rm "$config_map_aws_auth"' EXIT

pushd terraform
terraform output kubeconfig          > "$KUBECONFIG"
terraform output config_map_aws_auth > "$config_map_aws_auth"
popd

kubectl="${TOP}/util/kubectl.sh"
"$kubectl" apply -f "$config_map_aws_auth"
"$kubectl" apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
for file in k8s/*.yaml; do
  "$kubectl" apply -f "$file"
done
