#!/bin/sh

NAMESPACE="$1"
JUMPBOX="$2"

if [[ -z "$NAMESPACE" ]] || [[ -z "$JUMPBOX" ]] || [[ ! -e "${NAMESPACE}/deploy.sh" ]]; then
    echo "usage: $0 <namespace> <jumpbox ip>"
    exit 1
fi

set -e

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r "$NAMESPACE" "root@${JUMPBOX}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${JUMPBOX}" "./${NAMESPACE}/deploy.sh"
