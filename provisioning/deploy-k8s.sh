#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE"

pushd terraform
HOST="$(terraform output public-ssh-ip)"
SLAVES="$(terraform output k8s_slaves)"
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r k8s "root@${HOST}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${HOST}" ./k8s/deploy.sh "$SLAVES"
