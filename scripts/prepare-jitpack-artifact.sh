#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RELEASE_VERSION=${RELEASE_VERSION:-${VERSION:-}}

if [[ ! "$RELEASE_VERSION" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "RELEASE_VERSION must identify a release tag." >&2
  exit 1
fi

AAR_NAME="aniyomi-ffmpeg-kit-$RELEASE_VERSION.aar"
RELEASE_URL="https://github.com/bee-san/ffmpeg-kit/releases/download/$RELEASE_VERSION"
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

curl \
  --fail \
  --location \
  --retry 3 \
  --retry-all-errors \
  --output "$STAGING_DIR/$AAR_NAME" \
  "$RELEASE_URL/$AAR_NAME"
curl \
  --fail \
  --location \
  --retry 3 \
  --retry-all-errors \
  --output "$STAGING_DIR/SHA256SUMS" \
  "$RELEASE_URL/SHA256SUMS"

expected_sha256=$(
  awk -v artifact="$AAR_NAME" '$2 == artifact { print $1 }' "$STAGING_DIR/SHA256SUMS"
)
if [[ ! "$expected_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "SHA256SUMS must contain exactly one checksum for $AAR_NAME." >&2
  exit 1
fi

actual_sha256=$(sha256sum "$STAGING_DIR/$AAR_NAME" | cut -d ' ' -f 1)
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "$AAR_NAME does not match the GitHub release checksum." >&2
  exit 1
fi
jar tf "$STAGING_DIR/$AAR_NAME" > /dev/null

output_directory="$ROOT_DIR/android/ffmpeg-kit-android-lib/build/outputs/aar"
mkdir -p "$output_directory"
install -m 0644 "$STAGING_DIR/$AAR_NAME" "$output_directory/ffmpeg-kit-release.aar"
