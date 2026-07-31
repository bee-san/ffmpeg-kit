#!/usr/bin/env bash

set -euo pipefail

readonly RELEASE_VERSION="${RELEASE_VERSION:-}"
readonly EXPECTED_VERSION="1.17.4.1"
readonly EXPECTED_AAR_SHA256="d1a96fe0cf795a9cffb35dce20e2e2e6db17161a42f4ca5ef20b81f0892f317f"

if [[ "${RELEASE_VERSION}" != "${EXPECTED_VERSION}" ]]; then
  echo "RELEASE_VERSION must be ${EXPECTED_VERSION}, got '${RELEASE_VERSION}'." >&2
  exit 1
fi

readonly NATIVE_TAG="1.17.4-native"
readonly AAR_NAME="aniyomi-ffmpeg-kit-${NATIVE_TAG}.aar"
readonly AAR_PATH="android/ffmpeg-kit-android-lib/build/outputs/aar/ffmpeg-kit-release.aar"
readonly RELEASE_URL="https://github.com/bee-san/ffmpeg-kit/releases/download/${NATIVE_TAG}/${AAR_NAME}"

mkdir -p "$(dirname "${AAR_PATH}")"
curl --fail --location --retry 3 --output "${AAR_PATH}" "${RELEASE_URL}"
printf '%s  %s\n' "${EXPECTED_AAR_SHA256}" "${AAR_PATH}" | sha256sum --check --strict
jar tf "${AAR_PATH}" >/dev/null
