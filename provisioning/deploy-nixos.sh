#!/bin/sh

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

pushd terraform
HOST="$(terraform output public-ssh-ip)"
SLAVES="$(terraform output k8s_slaves)"
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r nixos "root@${HOST}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${HOST}" ./nixos/deploy.sh "$SLAVES"
