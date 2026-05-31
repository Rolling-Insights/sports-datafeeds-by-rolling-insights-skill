#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${ROLLING_INSIGHTS_BASE_URL:-https://rest.datafeeds.rolling-insights.com/api/v1}"
TOKEN="${RSC_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "Missing token: set RSC_TOKEN" >&2
  exit 1
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: df-rest.sh <endpoint> <date> <sport> [game_id]" >&2
  exit 1
fi

ENDPOINT="$1"
DATE="$2"
SPORT="${3:-}"
GAME_ID="${4:-}"

BUSTER="$(python3 -c 'import time;print(int(time.time()*1000))' 2>/dev/null || date +%s)"
URL="${BASE_URL}/${ENDPOINT}/${DATE}/${SPORT}?RSC_token=${TOKEN}&_=${BUSTER}"
if [[ -n "${GAME_ID}" ]]; then
  URL+="&game_id=${GAME_ID}"
fi

echo "${URL/${TOKEN}/REDACTED}" >&2

TMP_BODY="$(mktemp)"
TMP_HEADERS="$(mktemp)"
trap 'rm -f "${TMP_BODY}" "${TMP_HEADERS}"' EXIT

if ! curl -sS -D "${TMP_HEADERS}" -o "${TMP_BODY}" \
  -H 'Accept: application/json' \
  -H 'Cache-Control: no-cache, no-store' \
  -H 'Pragma: no-cache' \
  "${URL}"; then
  echo "HTTP request failed" >&2
  exit 1
fi

if ! jq -e . < "${TMP_BODY}" >/dev/null; then
  cat "${TMP_BODY}" >&2
  echo "Malformed JSON response" >&2
  exit 1
fi

cat "${TMP_BODY}"
