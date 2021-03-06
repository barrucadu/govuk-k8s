#!/usr/bin/env bash

set -e

TERRAFORM="$(git rev-parse --show-toplevel)/provisioning/terraform"
cd "$TERRAFORM"

if [[ ! -e terraform.tfstate ]]; then
    echo "Infrastructure has not been provisioned."
    exit 1
fi

SSH_IP="$(terraform output public-ssh-ip)"
WEB_IP="$(terraform output public-web-ip)"
EXTERNAL_DOMAIN="$(terraform output external-domain)"

echo "govuk-k8s running on ${SSH_IP} (ssh) and ${WEB_IP} (http/https)"
echo
echo "for external access, set the nameservers for ${EXTERNAL_DOMAIN} to"
terraform output name-servers
