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

cp docker-compose.yaml.template docker-compose.yaml
sed -i "s/TPL_GITHUB_USER/${GITHUB_USER}/" docker-compose.yaml
sed -i "s/TPL_GITHUB_CLIENT_ID/${GITHUB_CLIENT_ID}/" docker-compose.yaml
sed -i "s/TPL_GITHUB_CLIENT_SECRET/${GITHUB_CLIENT_SECRET}/" docker-compose.yaml

export COMPOSE_PROJECT_NAME="govuk_k8s_local"

docker-compose up -d

export KUBECONFIG

# kind + insecure docker registry set-up:
# https://kind.sigs.k8s.io/docs/user/local-registry/
REGISTRY_HOSTNAME="registry.govuk-k8s.test"
cat <<EOF | kind create cluster --name="$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."${REGISTRY_HOSTNAME}:5000"]
    endpoint = ["http://${REGISTRY_HOSTNAME}:5000"]
EOF

REGISTRY_IP="$(docker inspect --format '{{.NetworkSettings.Networks.govuk_k8s_local_network.IPAddress}}' govuk-k8s-registry)"
for node in $(kind get nodes --name="$CLUSTER_NAME"); do
  docker exec "${node}" sh -c "echo $REGISTRY_IP $REGISTRY_HOSTNAME >> /etc/hosts"
done

kubectl="${TOP}/util/kubectl.sh"
for f in k8s/*.yaml; do
  "$kubectl" apply -f "$f"
done

echo
echo "add these entries to your /etc/hosts file:"
echo
./etc-hosts-entries.sh
