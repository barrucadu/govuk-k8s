#!/bin/sh

set -e

pushd terraform
HOST="$(terraform output public_ip)"
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r nixos "root@${HOST}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${HOST}" ./nixos/deploy.sh
