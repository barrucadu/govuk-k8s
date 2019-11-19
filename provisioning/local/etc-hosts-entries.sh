#!/usr/bin/env bash

set -e

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ "$MODE" != "local" ]]; then
    echo "MODE != local"
    exit 1
fi

CI_IP="$(docker inspect --format '{{.NetworkSettings.Networks.govuk_k8s_local_network.IPAddress }}' govuk-k8s-ci)"
REGISTRY_IP="$(docker inspect --format '{{.NetworkSettings.Networks.govuk_k8s_local_network.IPAddress }}' govuk-k8s-registry)"

echo "${CI_IP} ci.govuk-k8s.test"
echo "${REGISTRY_IP} registry.govuk-k8s.test"

cd "${TOP}/kubernetes"
for d in *; do
  if [[ -e "$d/secrets.yaml" ]]; then
      echo "127.0.0.1 www-origin.$d.govuk-k8s.test"
  fi
done
for f in */*.service.yaml; do
  if grep -q Ingress "$f"; then
      host="$(grep host "$f" | sed 's/.*: //')"
      echo "127.0.0.1 ${host}"
  fi
done
