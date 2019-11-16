#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

pushd terraform
HOST="$(terraform output public-ssh-ip)"
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r nixos "root@${HOST}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${HOST}" ./nixos/deploy.sh
