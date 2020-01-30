#!/usr/bin/env bash

NAMESPACE="$1"

HERE="$(git rev-parse --show-toplevel)/kubernetes"
cd "$HERE"

if [[ -z "$NAMESPACE" ]] || [[ ! -e "${NAMESPACE}/secrets.yaml.template" ]]; then
    echo "usage: $0 <namespace>"
    exit 1
fi

cd "$(git rev-parse --show-toplevel)/provisioning/terraform"
JUMPBOX="$(terraform output public-ssh-ip)"

cd "$HERE"

source "$(git rev-parse --show-toplevel)/config"

cd "$NAMESPACE"

case "$ENABLE_HTTPS" in
  "true")
    echo "./apps.dhall True \"${EXTERNAL_DOMAIN_NAME}\"" | dhall-to-json > apps.yaml
    ;;
  *)
    echo "./apps.dhall False \"${EXTERNAL_DOMAIN_NAME}\"" | dhall-to-json > apps.yaml
    ;;
esac

cp secrets.yaml.template secrets.yaml
# generate a fresh SECRET_KEY_BASE every time
while grep -q TPL_UUID secrets.yaml; do
  sed -i -e "/TPL_UUID/{s//$(uuidgen)/;:a" -e '$!N;$!ba' -e '}' secrets.yaml
done

kubectl="$(git rev-parse --show-toplevel)/util/kubectl.sh"
for file in *.yaml; do
  "$kubectl" --namespace "$NAMESPACE" apply -f "$file"
done
