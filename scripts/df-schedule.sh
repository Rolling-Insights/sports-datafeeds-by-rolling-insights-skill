#!/usr/bin/env bash
# Thin compatibility wrapper over df.sh (the primary runner). Same positional
# interface as before; diagnostics, redaction, and exit codes come from df.sh.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE="${1:-}"
SPORT="${2:-}"
EXTRA="${3:-}"

if [[ -z "${DATE}" || -z "${SPORT}" ]]; then
  echo "Usage: df-schedule.sh <date> <sport> [game_id=X|league=X]" >&2
  exit 2
fi

# The optional third argument may carry several "&"-joined key=value pairs.
PARAMS=()
if [[ -n "${EXTRA}" ]]; then
  IFS='&' read -r -a PARAMS <<< "${EXTRA}"
fi

exec "${DIR}/df.sh" schedule "${DATE}" "${SPORT}" ${PARAMS[@]+"${PARAMS[@]}"}
