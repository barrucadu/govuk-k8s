#!/usr/bin/env bash

set -e

TERRAFORM="$(git rev-parse --show-toplevel)/provisioning/terraform"
cd "$TERRAFORM"

if [[ ! -e terraform.tfstate ]]; then
    echo "Infrastructure has not been provisioned."
    exit 1
fi

SSH_IP="$(terraform output public-ssh-ip)"

exec ssh -A "root@${SSH_IP}" "$@"
