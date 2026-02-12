#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/check-latest-version.sh [--version VERSION]

Prints GitHub Actions output lines:
  current_version=<version>
  new_version=<version>
  update_needed=true|false
EOF
}

VERSION_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION_ARG="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

CURRENT_VERSION=$(grep 'version = ' package.nix | cut -d'"' -f2 | head -1)

if [[ -n "$VERSION_ARG" ]]; then
  LATEST_VERSION="$VERSION_ARG"
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "Missing required command: gh" >&2
    exit 1
  fi
  LATEST_VERSION=$(gh release view --repo zed-industries/zed --json tagName -q '.tagName' | sed 's/^rust-v//' || echo "")
fi

if [[ -z "$LATEST_VERSION" ]]; then
  echo "Could not fetch latest version" >&2
  exit 1
fi

echo "current_version=$CURRENT_VERSION"
echo "new_version=$LATEST_VERSION"

if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
  echo "update_needed=true"
else
  echo "update_needed=false"
fi
