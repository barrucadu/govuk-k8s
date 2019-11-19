#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ "$MODE" != "aws" ]]; then
    echo "MODE != aws"
    exit 1
fi

TERRAFORM="${TOP}/provisioning/aws/terraform"
cd "$TERRAFORM"

if [[ ! -e terraform.tfstate ]]; then
    echo "Infrastructure has not been provisioned."
    exit 1
fi

SSH_IP="$(terraform output public-ssh-ip)"

exec ssh -A "root@${SSH_IP}" "$@"
