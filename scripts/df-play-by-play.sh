#!/usr/bin/env bash
# Thin compatibility wrapper over df.sh (the primary runner). Same positional
# interface as before; diagnostics, redaction, and exit codes come from df.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPORT="${1:-}"
GAME_ID="${2:-}"

if [[ -z "${SPORT}" || -z "${GAME_ID}" ]]; then
  echo "Usage: df-play-by-play.sh <sport> <game_id>" >&2
  exit 2
fi

case "${SPORT}" in
  MLB|NBA|NFL) ;;
  *) echo "Unsupported play-by-play sport: ${SPORT}. Documented support: MLB, NBA, NFL" >&2; exit 2 ;;
esac

exec "${DIR}/df.sh" play-by-play "${SPORT}" "game_id=${GAME_ID}"
