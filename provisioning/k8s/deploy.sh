#!/bin/sh

MASTER="k8s-master.govuk-k8s.test"
SLAVES="$1"

set -ex

secret=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$MASTER" cat /var/lib/kubernetes/secrets/apitoken.secret)
for i in $(seq 0 "$((SLAVES - 1))"); do
  slave_host="k8s-slave-${i}"
  echo $secret | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${slave_host}.govuk-k8s.test" nixos-kubernetes-node-join
done

scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r k8s/ "${MASTER}:"
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$MASTER" <<EOF
set -ex
echo "export KUBECONFIG=/etc/kubernetes/cluster-admin.kubeconfig" > .bashrc
source .bashrc
kubectl apply -f k8s/helm-rbac.yaml
helm init --service-account=tiller
EOF
