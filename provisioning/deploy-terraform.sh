#!/bin/sh

set -e

HERE="$(git rev-parse --show-toplevel)/provisioning"
cd "$HERE/terraform"

terraform apply "$@"
