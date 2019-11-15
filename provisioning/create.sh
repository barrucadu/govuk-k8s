#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

./deploy-terraform.sh
./deploy-nixos.sh
./deploy-k8s.sh

../util/infra-info.sh
