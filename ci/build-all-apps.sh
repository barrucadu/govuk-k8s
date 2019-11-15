#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/ci"
cd "$HERE"

if [[ -z "$FLY_LOGGED_IN" ]]; then
    ./concourse/login.sh
fi

fly trigger-job -t govuk-k8s -j ci/govuk-base
fly trigger-job -t govuk-k8s -j ci/fake-router
