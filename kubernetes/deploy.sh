#!/usr/bin/env bash

NAMESPACE="$1"

HERE="$(git rev-parse --show-toplevel)/kubernetes"
cd "$HERE"

if [[ -z "$NAMESPACE" ]] || [[ ! -e "${NAMESPACE}/apps.dhall" ]]; then
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

if [[ ! -e secrets.yaml ]]; then
  cat <<EOF > secrets.yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: govuk
stringData:
  SECRET_KEY_BASE-calculators: $(uuidgen)
  SECRET_KEY_BASE-calendars: $(uuidgen)
  SECRET_KEY_BASE-collections: $(uuidgen)
  SECRET_KEY_BASE-finder-frontend: $(uuidgen)
  SECRET_KEY_BASE-frontend: $(uuidgen)
  SECRET_KEY_BASE-government-frontend: $(uuidgen)
  SECRET_KEY_BASE-info-frontend: $(uuidgen)
  SECRET_KEY_BASE-manuals-frontend: $(uuidgen)
  SECRET_KEY_BASE-service-manual-frontend: $(uuidgen)
  SECRET_KEY_BASE-smart-answers: $(uuidgen)
EOF
fi

kubectl="$(git rev-parse --show-toplevel)/util/kubectl.sh"
for file in *.yaml; do
  "$kubectl" --namespace "$NAMESPACE" apply -f "$file"
done
