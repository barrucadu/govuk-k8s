#!/usr/bin/env bash

packages=(aws-iam-authenticator jq kubectl "python3.withPackages (ps: [ps.pyyaml])" python3Packages.black shellcheck terraform)

if [[ "$#" == "0" ]]; then
  exec nix-shell -p "${packages[@]}"
else
  exec nix-shell -p "${packages[@]}" --command "$@"
fi
