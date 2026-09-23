#!/usr/bin/env bash
# Thin compatibility wrapper over df.sh (the primary runner). Same positional
# interface as before; diagnostics, redaction, and exit codes come from df.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPORT="${1:-}"
GAME_ID="${2:-}"

if [[ -z "${SPORT}" || -z "${GAME_ID}" ]]; then
  echo "Usage: df-field.sh <sport> <game_id>" >&2
  exit 2
fi

exec "${DIR}/df.sh" field "${SPORT}" "game_id=${GAME_ID}"
