#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUTPUT_PATH=${1:-"$ROOT_DIR/ffmpeg-kit-source.tar.gz"}
OUTPUT_PATH=$(realpath -m "$OUTPUT_PATH")
MPV_ROOT="$ROOT_DIR/aniyomi-mpv-lib"
MPV_DEPS="$MPV_ROOT/buildscripts/deps"
SOURCE_DIR="$ROOT_DIR/src"

. "$ROOT_DIR/scripts/chimahon-native-lock.sh"
. "$MPV_ROOT/buildscripts/include/depinfo.sh"

assert_revision() {
  local repository="$1"
  local expected="$2"
  local actual
  actual=$(git -C "$repository" rev-parse HEAD)
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $repository revision $expected, found $actual" >&2
    exit 1
  fi
}

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

assert_revision "$MPV_ROOT" "$v_aniyomi_mpv_commit"
assert_revision "$MPV_DEPS/dav1d" "$v_dav1d"
assert_revision "$MPV_DEPS/ffmpeg" "$v_ffmpeg_commit"
assert_revision "$MPV_DEPS/freetype2" "$v_freetype_commit"
assert_revision "$MPV_DEPS/libass" "$v_libass"
assert_revision "$MPV_DEPS/libplacebo" "$v_libplacebo"
assert_revision "$MPV_DEPS/mpv" "$v_mpv"
assert_revision "$SOURCE_DIR/ffmpeg" "$v_ffmpeg_reference_commit"
assert_revision "$SOURCE_DIR/cpu-features" "$v_cpu_features_commit"

for dependency in freetype2 libplacebo; do
  if git -C "$MPV_DEPS/$dependency" submodule status --recursive | grep -Eq '^[+-U]'; then
    echo "$dependency contains an uninitialized, mismatched, or conflicted submodule" >&2
    exit 1
  fi
done

GAS_PREPROCESSOR="$MPV_ROOT/buildscripts/sdk/bin/gas-preprocessor.pl"
if [[ ! -f "$GAS_PREPROCESSOR" ]] ||
  [[ "$(sha256 "$GAS_PREPROCESSOR")" != "$v_gas_preprocessor_sha256" ]]; then
  echo "Missing or mismatched gas-preprocessor.pl" >&2
  exit 1
fi

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT
SOURCE_ROOT="$STAGING_DIR/ffmpeg-kit-source"
mkdir -p "$SOURCE_ROOT"

git -C "$ROOT_DIR" archive HEAD | tar -x -C "$SOURCE_ROOT"
mkdir -p "$SOURCE_ROOT/aniyomi-mpv-lib"
git -C "$MPV_ROOT" archive HEAD | tar -x -C "$SOURCE_ROOT/aniyomi-mpv-lib"
cp -a "$MPV_DEPS" "$SOURCE_ROOT/aniyomi-mpv-lib/buildscripts/deps"
mkdir -p "$SOURCE_ROOT/aniyomi-mpv-lib/buildscripts/sdk/bin"
cp "$GAS_PREPROCESSOR" \
  "$SOURCE_ROOT/aniyomi-mpv-lib/buildscripts/sdk/bin/gas-preprocessor.pl"
cp -a "$SOURCE_DIR" "$SOURCE_ROOT/src"
find "$SOURCE_ROOT" -name .git -type f -delete
find "$SOURCE_ROOT" -name .git -type d -prune -exec rm -rf {} +

cat > "$SOURCE_ROOT/SOURCE-LOCK.txt" <<LOCK
wrapper=$(git -C "$ROOT_DIR" rev-parse HEAD)
aniyomi_mpv_tag=$v_aniyomi_mpv_tag
aniyomi_mpv=$v_aniyomi_mpv_commit
android_command_line_tools=$v_sdk
android_ndk=$v_ndk_n
android_sdk_platform=$v_sdk_platform
android_build_tools=$v_sdk_build_tools
gas_preprocessor=$v_gas_preprocessor
gas_preprocessor_sha256=$v_gas_preprocessor_sha256
mbedtls=$v_mbedtls
mbedtls_archive_sha256=$v_mbedtls_sha256
libxml2=$v_libxml2
libxml2_archive_sha256=$v_libxml2_sha256
dav1d=$v_dav1d
ffmpeg=$v_ffmpeg_commit
freetype=$v_freetype_commit
fribidi=$v_fribidi
fribidi_archive_sha256=$v_fribidi_sha256
harfbuzz=$v_harfbuzz
harfbuzz_archive_sha256=$v_harfbuzz_sha256
libunibreak=$v_unibreak
libunibreak_archive_sha256=$v_unibreak_sha256
libass=$v_libass
lua=$v_lua
lua_archive_sha256=$v_lua_sha256
libplacebo=$v_libplacebo
mpv=$v_mpv
ffmpeg_reference=$v_ffmpeg_reference_commit
cpu_features=$v_cpu_features_commit
protocol_libavformat_file_sha256=$(sha256 "$MPV_DEPS/ffmpeg/libavformat/file.c")
protocol_libavformat_protocols_sha256=$(sha256 "$MPV_DEPS/ffmpeg/libavformat/protocols.c")
protocol_libavutil_file_header_sha256=$(sha256 "$MPV_DEPS/ffmpeg/libavutil/file.h")
protocol_libavutil_file_source_sha256=$(sha256 "$MPV_DEPS/ffmpeg/libavutil/file.c")
LOCK

for dependency in freetype2 libplacebo; do
  git -C "$MPV_DEPS/$dependency" submodule status --recursive |
    sed "s|^|${dependency}_submodule=|" >> "$SOURCE_ROOT/SOURCE-LOCK.txt"
done

tar \
  --sort=name \
  --mtime='UTC 1970-01-01' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -cf - \
  -C "$STAGING_DIR" \
  ffmpeg-kit-source |
  gzip -n > "$OUTPUT_PATH"

sha256sum "$OUTPUT_PATH"
