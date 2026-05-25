#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${ROLLING_INSIGHTS_BASE_URL:-https://rest.datafeeds.rolling-insights.com/api/v1}"
TOKEN="${RSC_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "Missing token: set RSC_TOKEN" >&2
  exit 1
fi

SPORT="${1:-}"
GAME_ID="${2:-}"

if [[ -z "${SPORT}" || -z "${GAME_ID}" ]]; then
  echo "Usage: df-play-by-play.sh <sport> <game_id>" >&2
  exit 1
fi

case "${SPORT}" in
  MLB|NBA|NFL) ;;
  *) echo "Unsupported play-by-play sport: ${SPORT}. Documented support: MLB, NBA, NFL" >&2; exit 1 ;;
esac

BUSTER="$(python3 -c 'import time;print(int(time.time()*1000))' 2>/dev/null || date +%s)"
URL="${BASE_URL}/play-by-play/${SPORT}?RSC_token=${TOKEN}&game_id=${GAME_ID}&_=${BUSTER}"
echo "${URL/${TOKEN}/REDACTED}" >&2

TMP_BODY="$(mktemp)"
trap 'rm -f "${TMP_BODY}"' EXIT

HTTP_CODE="$(curl -sS -w '%{http_code}' -o "${TMP_BODY}" \
  -H 'Accept: application/json' \
  -H 'Cache-Control: no-cache, no-store' \
  -H 'Pragma: no-cache' \
  "${URL}" || true)"
if [[ "${HTTP_CODE}" -eq 304 ]]; then
  echo "304 Not Modified" >&2
  exit 1
fi
if [[ "${HTTP_CODE}" -ge 400 ]]; then
  cat "${TMP_BODY}" >&2
  echo "HTTP error ${HTTP_CODE}" >&2
  exit 1
fi

if ! jq -e . < "${TMP_BODY}" >/dev/null; then
  cat "${TMP_BODY}" >&2
  echo "Malformed JSON response" >&2
  exit 1
fi

cat "${TMP_BODY}"
