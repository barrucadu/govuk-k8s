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

pushd terraform
HOST="$(terraform output public-ssh-ip)"
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r nixos "root@${HOST}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${HOST}" ./nixos/deploy.sh
