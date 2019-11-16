#!/usr/bin/env bash

source "$(git rev-parse --show-toplevel)/config"
export AWS_PROFILE
export KUBECONFIG

kubectl "$@"
