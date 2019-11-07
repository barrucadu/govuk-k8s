#!/bin/sh

set -e

./deploy-terraform.sh

pushd terraform
HOST="$(terraform output public_ip)"
popd

echo "govuk-k8s running on ${HOST}"
