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

./deploy-terraform.sh
./deploy-nixos.sh
./deploy-k8s.sh

"${TOP}/util/infra-info.sh"
