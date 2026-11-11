#!/usr/bin/env bash
# Builds the admin app (oas-web) and the public app (oas-web-public) once each,
# then fails if anything in either build output mentions "oxfordshire" in any
# case. One build of each app must serve any society, so the society's name,
# domain and wording have to come from the server at run time, never from the
# bundle.
#
# Usage: scripts/check-no-oxfordshire.sh [--skip-build]
#   --skip-build  only search the existing build/ folders.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apps=(oas-web oas-web-public)
skip_build=false
[[ "${1:-}" == "--skip-build" ]] && skip_build=true

for app in "${apps[@]}"; do
  dir="$root/$app"
  if [[ "$skip_build" == false ]]; then
    echo "==> Building $app"
    if [[ ! -d "$dir/node_modules" ]]; then
      (cd "$dir" && npm ci)
    fi
    # CI=false stops create-react-app treating old lint warnings as errors.
    (cd "$dir" && CI=false npm run build)
  fi
  if [[ ! -d "$dir/build" ]]; then
    echo "error: $app/build does not exist; run without --skip-build" >&2
    exit 2
  fi
done

found=0
for app in "${apps[@]}"; do
  echo "==> Searching $app/build for \"oxfordshire\""
  if matches="$(grep -rilI --binary-files=without-match oxfordshire "$root/$app/build")"; then
    found=1
    echo "Found in:"
    echo "$matches" | sed "s|^$root/|  |"
    # Show a little context around each match, so it can be traced to source.
    grep -rioIh '.\{0,60\}oxfordshire.\{0,60\}' "$root/$app/build" | sort -u | head -20 | sed 's/^/    /'
  fi
done

if [[ "$found" == 1 ]]; then
  echo "FAIL: the build output mentions Oxfordshire" >&2
  exit 1
fi
echo "OK: no Oxfordshire text in either build"
