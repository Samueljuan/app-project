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

echo "Flutter version:"
flutter --version

flutter config --enable-web >/dev/null

flutter pub get
flutter build web
