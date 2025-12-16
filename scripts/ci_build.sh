#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.22.2}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${ARCHIVE}"

if [ ! -d flutter ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}-${FLUTTER_CHANNEL}..."
  curl -sSLo "${ARCHIVE}" "${DOWNLOAD_URL}"
  tar xf "${ARCHIVE}"
  rm "${ARCHIVE}"
fi

export PATH="$PWD/flutter/bin:$PATH"

git config --global --add safe.directory "$PWD/flutter" >/dev/null 2>&1 || true

echo "Flutter version:"
flutter --version

flutter config --enable-web >/dev/null

flutter pub get

build_args=(build web)

if [ -z "${APPS_SCRIPT_URL:-}" ]; then
  echo "WARNING: APPS_SCRIPT_URL env variable is empty. Build will use empty URL."
else
  build_args+=("--dart-define=APPS_SCRIPT_URL=${APPS_SCRIPT_URL}")
fi

if [ -n "${LOGIN_USERNAME:-}" ]; then
  build_args+=("--dart-define=LOGIN_USERNAME=${LOGIN_USERNAME}")
fi

if [ -n "${LOGIN_PASSWORD:-}" ]; then
  build_args+=("--dart-define=LOGIN_PASSWORD=${LOGIN_PASSWORD}")
fi

if [ -n "${LOGIN_PASSWORD_HASH:-}" ]; then
  build_args+=("--dart-define=LOGIN_PASSWORD_HASH=${LOGIN_PASSWORD_HASH}")
fi

flutter "${build_args[@]}"
