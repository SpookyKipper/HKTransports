#!/usr/bin/env bash
set -euo pipefail

VERSION_LINE="$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml)"
if [[ -z "${VERSION_LINE}" ]]; then
  echo "Unable to read version from pubspec.yaml" >&2
  exit 1
fi

APP_VERSION="${VERSION_LINE%%+*}"
APP_BUILD="${VERSION_LINE#*+}"
if [[ "${APP_BUILD}" == "${VERSION_LINE}" ]]; then
  APP_BUILD=0
fi

flutter build apk --release --obfuscate \
  --split-debug-info=./debug-info \
  --dart-define=APP_VERSION="${APP_VERSION}" \
  --dart-define=APP_BUILD="${APP_BUILD}"
