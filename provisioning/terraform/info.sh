#!/bin/sh

set -e

IP="$(terraform output public_ip)"
EXTERNAL_DOMAIN="$(terraform output external_domain)"

echo "govuk-k8s running on ${IP}"
echo
echo "for external access, set the nameservers for ${EXTERNAL_DOMAIN} to"
terraform output name_servers
