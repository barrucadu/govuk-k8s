#!/usr/bin/env bash

set -e

NAMESPACE="$1"

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

HERE="${TOP}/kubernetes"
cd "$HERE"

if [[ -z "$NAMESPACE" ]] || [[ ! -e "${NAMESPACE}/secrets.yaml.template" ]]; then
    echo "usage: $0 <namespace>"
    exit 1
fi

cd "$NAMESPACE"

enable_https="${ENABLE_HTTPS:-false}"
external_domain_name="${EXTERNAL_DOMAIN_NAME:-govuk-k8s.test}"

cp secrets.yaml.template secrets.yaml
sed -i "s/TPL_ENABLE_HTTPS/${enable_https}/" secrets.yaml
sed -i "s/TPL_EXTERNAL_DOMAIN_NAME/${external_domain_name}/" secrets.yaml

# generate a fresh SECRET_KEY_BASE every time
while grep -q TPL_UUID secrets.yaml; do
  sed -i -e "/TPL_UUID/{s//$(uuidgen)/;:a" -e '$!N;$!ba' -e '}' secrets.yaml
done

kubectl="${TOP}/util/kubectl.sh"

for service in *.service.yaml; do
  app="${service//.service.yaml/}"
  "$kubectl" --namespace "$NAMESPACE" apply -f "../apps/${app}.deployment.yaml"
done

for file in *.yaml; do
  "$kubectl" --namespace "$NAMESPACE" apply -f "$file"
done
