#!/usr/bin/env bash

TOP="$(git rev-parse --show-toplevel)"
source "${TOP}/config"

if [[ -z "${MODE:-}" ]]; then
  echo "bad mode"
  exit 1
fi

SCRIPT="${TOP}/provisioning/${MODE}/destroy.sh"

if [[ ! -x "$SCRIPT" ]]; then
    echo "bad mode"
    exit 1
fi

"$SCRIPT"
