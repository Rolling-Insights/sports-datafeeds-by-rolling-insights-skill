#!/usr/bin/env bash
# Thin compatibility wrapper over df.sh (the primary runner) for the original
# date-based form. Same positional interface as before; df.sh now also checks the
# HTTP status (this script previously passed any status through as success).
# For season-based or date-less endpoints, or --probe, call df.sh directly.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 3 ]]; then
  echo "Usage: df-rest.sh <endpoint> <date> <sport> [game_id]" >&2
  echo "For other endpoint shapes use: df.sh <endpoint> [<date>|<season>] <sport> [key=value ...]" >&2
  exit 2
fi

ENDPOINT="$1"
DATE="$2"
SPORT="$3"
GAME_ID="${4:-}"

if [[ -n "${GAME_ID}" ]]; then
  exec "${DIR}/df.sh" "${ENDPOINT}" "${DATE}" "${SPORT}" "game_id=${GAME_ID}"
fi
exec "${DIR}/df.sh" "${ENDPOINT}" "${DATE}" "${SPORT}"
