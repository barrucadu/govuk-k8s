#!/usr/bin/env bash

set -e

HERE="$(git rev-parse --show-toplevel)/ci/concourse"
cd "$HERE"

source "$(git rev-parse --show-toplevel)/config"

URL="http://ci.${EXTERNAL_DOMAIN_NAME}"
if $ENABLE_HTTPS; then
    URL="https://ci.${EXTERNAL_DOMAIN_NAME}"
fi

fly login -t govuk-k8s -c "$URL"
