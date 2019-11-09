#!/bin/sh

set -e

./deploy-terraform.sh
./deploy-nixos.sh
./deploy-k8s.sh

cd terraform
./info.sh
