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

KMB_ETA_SECRET_FILE="${KMB_ETA_SECRET_FILE:-secrets/kmb_eta.json}"
if [[ ! -f "${KMB_ETA_SECRET_FILE}" ]]; then
  echo "Missing local KMB ETA secret file: ${KMB_ETA_SECRET_FILE}" >&2
  exit 1
fi

flutter build apk --release --obfuscate \
  --split-debug-info=./debug-info \
  --dart-define=APP_VERSION="${APP_VERSION}" \
  --dart-define=APP_BUILD="${APP_BUILD}" \
  --dart-define-from-file="${KMB_ETA_SECRET_FILE}"
