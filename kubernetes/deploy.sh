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

source ../config

pushd "$NAMESPACE"

cp secrets.yaml.template secrets.yaml
sed -i "s/EXTERNAL_DOMAIN_NAME/${EXTERNAL_DOMAIN_NAME}/" secrets.yaml

# generate a fresh SECRET_KEY_BASE every time
while grep -q GENERATED_SECRET_KEY_BASE secrets.yaml; do
  sed -i -e "/GENERATED_SECRET_KEY_BASE/{s//$(uuidgen)/;:a" -e '$!N;$!ba' -e '}' secrets.yaml
done

for service in *.service.yaml; do
  app="${service//.service.yaml/}"
  cp "../apps/${app}.deployment.yaml" .
done
popd

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r "$NAMESPACE" "root@${JUMPBOX}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "root@${JUMPBOX}" <<EOF
set -ex
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r "$NAMESPACE" k8s-master.govuk-k8s.test:
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no k8s-master.govuk-k8s.test <<INNER
set -ex
source .bashrc
cd "$NAMESPACE"
for file in *.yaml; do
  kubectl --namespace "$NAMESPACE" apply -f \\\$file
done
INNER
EOF
