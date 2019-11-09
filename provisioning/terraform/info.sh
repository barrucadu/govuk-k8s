#!/bin/sh

set -e

if [[ ! -e main.tf ]]; then
    echo "run me from the terraform directory"
    exit 1
fi

SSH_IP="$(terraform output public-ssh-ip)"
WEB_IP="$(terraform output public-web-ip)"
EXTERNAL_DOMAIN="$(terraform output external-domain)"

echo "govuk-k8s running on ${SSH_IP} (ssh) and ${WEB_IP} (http/https)"
echo
echo "for external access, set the nameservers for ${EXTERNAL_DOMAIN} to"
terraform output name-servers
