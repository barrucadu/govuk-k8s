#!/bin/sh

SLAVES="$1"

set -ex

secret=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no k8s-master.govuk-k8s.test cat /var/lib/kubernetes/secrets/apitoken.secret)
for i in $(seq 0 "$((SLAVES - 1))"); do
  slave_host="k8s-slave-${i}"
  echo $secret | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "${slave_host}.govuk-k8s.test" nixos-kubernetes-node-join
done
