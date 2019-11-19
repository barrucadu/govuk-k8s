#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ "$MODE" != "local" ]]; then
    echo "MODE != local"
    exit 1
fi

HERE="${TOP}/provisioning/local"
cd "$HERE"

CLUSTER_NAME="govuk-k8s"
export COMPOSE_PROJECT_NAME="govuk_k8s_local"

docker-compose down

rm "$KUBECONFIG"

kind delete cluster --name="$CLUSTER_NAME"

if grep -q govuk-k8s.test /etc/hosts; then
    echo "remove the extra entries from /etc/hosts"
fi
