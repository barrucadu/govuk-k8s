#!/bin/sh

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

./deploy-terraform.sh
./deploy-nixos.sh
./deploy-k8s.sh

./terraform/info.sh
