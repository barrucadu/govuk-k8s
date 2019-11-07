#!/bin/sh

set -e

pushd terraform
terraform apply "$@"
popd
