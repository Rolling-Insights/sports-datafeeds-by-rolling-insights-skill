#!/usr/bin/env bash
# df.sh: primary request runner for the DataFeeds by Rolling Insights REST API.
#
#   scripts/df.sh [flags] <endpoint> [<YYYY-MM-DD>|<YYYY>] <SPORT> [key=value ...]
#
# Run with --help for request shapes, flags, and the exit-code table.
#
# Token safety (public repo, query-string credential):
#   * the token is read from RSC_TOKEN only and handed to curl via --data-urlencode,
#     so it is never interpolated into a URL string;
#   * the stderr request echo is assembled from non-secret parts with a literal
#     "RSC_token=REDACTED";
#   * every other diagnostic line (curl messages, response headers, error-body
#     excerpts, the --probe summary) passes through redact(), a literal, non-pattern
#     replacement that treats the token as opaque data.
# Keep all three intact when changing this file.
set -euo pipefail

BASE_URL="${ROLLING_INSIGHTS_BASE_URL:-https://rest.datafeeds.rolling-insights.com/api/v1}"
CONNECT_TIMEOUT="${DF_CONNECT_TIMEOUT:-10}"
MAX_TIME="${DF_TIMEOUT:-60}"
BODY_EXCERPT_BYTES=4096
TRIAL_URL="https://accounts.rolling-insights.com/register"

EX_OK=0
EX_USAGE=2
EX_NO_TOKEN=3
EX_NETWORK=4
EX_TIMEOUT=5
EX_NOT_MODIFIED=6
EX_HTTP_ERROR=7
EX_NON_JSON=8
EX_MALFORMED_JSON=9

ENDPOINTS="schedule schedule-week schedule-season live events play-by-play field team-info team-stats player-info player-stats injuries depth-charts"
SPORTS="NHL NBA NFL MLB NCAABB NCAAFB SOCCER DARTS PGA"
PARAM_KEYS="game_id team_id player_id league event_id relegated"
SOCCER_LEAGUES="EPL LALIGA SERIEA"

usage() {
  cat <<'USAGE'
Usage: df.sh [flags] <endpoint> [<YYYY-MM-DD>|<YYYY>] <SPORT> [key=value ...]

One runner for every documented DataFeeds REST endpoint shape. Reads the token from
RSC_TOKEN, prints a redacted request line to stderr, emits raw JSON to stdout.

Request shapes (the second positional is the date/season segment; it is only taken
as such when it is numeric, so the shapes never collide):
  date-based    schedule | schedule-week | live | events          <YYYY-MM-DD> <SPORT>
  season-based  schedule-season                                  <YYYY|YYYY-MM-DD> <SPORT>
                team-stats | player-stats                        [<YYYY>] <SPORT>
  date-less     play-by-play | field | team-info | player-info | injuries | depth-charts
                                                                 <SPORT>

Sports: NHL NBA NFL MLB NCAABB NCAAFB SOCCER DARTS PGA   (NCAA_BB / NCAA_FB are normalized)
Params: game_id team_id player_id league event_id relegated   (values: [A-Za-z0-9_.-]+)
        SOCCER requires league=EPL|LALIGA|SERIEA. Never pass RSC_token as a parameter.

Flags:
  --probe              Same request, but print a one-line classification summary to
                       stdout instead of the body (http=, class=, bytes=, content_type=,
                       request=, and the JSON shape). For capability/entitlement checks.
  --dry-run            Print the redacted request line and exit 0. No token, no network.
  --unchecked          Skip the endpoint/sport/param allowlists and shape rules (to probe
                       undocumented forms). Value charset checks still apply.
  --timeout N          Total request timeout in seconds (default 60; env DF_TIMEOUT).
  --connect-timeout N  Connect timeout in seconds (default 10; env DF_CONNECT_TIMEOUT).
  -h, --help           This text.

Environment:
  RSC_TOKEN                  API token (required unless --dry-run / --help).
  ROLLING_INSIGHTS_BASE_URL  Base URL (default https://rest.datafeeds.rolling-insights.com/api/v1).
                             http:// is refused except for loopback hosts or DF_ALLOW_INSECURE=1.
  DF_TIMEOUT, DF_CONNECT_TIMEOUT   See --timeout / --connect-timeout.

Exit codes (each outcome is reported distinctly on stderr):
  0  HTTP 2xx with valid JSON (body on stdout)
  2  usage / validation error
  3  missing token
  4  network failure (curl could not complete the transfer; HTTP code 000)
  5  timeout (connect or total)
  6  HTTP 304 Not Modified (no body; see references/troubleshooting.md)
  7  HTTP error: 4xx / 5xx, or a redirect that was not followed (body excerpt on stderr)
  8  HTTP 2xx but the body is not JSON (empty, plain text, HTML)
  9  HTTP 2xx and the body looks like JSON but does not parse

Examples:
  df.sh schedule 2026-04-10 NBA
  df.sh live 2026-04-10 NBA game_id=20260410-1-2
  df.sh team-stats 2025 SOCCER league=EPL
  df.sh player-stats PGA
  df.sh play-by-play MLB game_id=20260515-9-8
  df.sh --probe depth-charts NCAAFB
USAGE
}

# ---------- helpers ----------

# Literal (non-pattern) replacement of the token in a string: the raw value and its
# percent-encoded form in both hex cases (curl builds vary). The quoted pattern in
# ${s//"..."/} disables glob matching (bash >= 3.2), so the token is opaque data.
TOKEN_ENC_UPPER=""
TOKEN_ENC_LOWER=""
redact() {
  local s="$1" enc
  if [[ -n "${RSC_TOKEN:-}" ]]; then
    s="${s//"${RSC_TOKEN}"/REDACTED}"
    for enc in "${TOKEN_ENC_UPPER}" "${TOKEN_ENC_LOWER}"; do
      if [[ -n "${enc}" && "${enc}" != "${RSC_TOKEN}" ]]; then
        s="${s//"${enc}"/REDACTED}"
      fi
    done
  fi
  printf '%s\n' "${s}"
}

# Percent-encode like curl --data-urlencode (unreserved: A-Z a-z 0-9 - . _ ~).
# Second argument selects the hex case: X (default) or x.
urlencode() {
  local s="$1" fmt="%%%02${2:-X}" out="" i c
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "${c}" in
      [A-Za-z0-9.~_-]) out+="${c}" ;;
      *) out+="$(printf "${fmt}" "'${c}")" ;;
    esac
  done
  printf '%s' "${out}"
}

die_usage() {
  redact "df.sh: $*" >&2
  echo "Run 'df.sh --help' for usage." >&2
  exit "${EX_USAGE}"
}

in_list() { # in_list <needle> "<space separated list>"
  local needle="$1" item
  for item in $2; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

endpoint_shape() {
  case "$1" in
    schedule|schedule-week|live|events) echo date ;;
    schedule-season) echo year-or-date ;;
    team-stats|player-stats) echo optional-year ;;
    play-by-play|field|team-info|player-info|injuries|depth-charts) echo none ;;
    *) echo unknown ;;
  esac
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# Last value of a response header (case-insensitive name), CR stripped, "-" if absent.
header_value() { # header_value <file> <name>
  tr -d '\r' < "$1" | awk -v want="$(lower "$2"):" '
    tolower($1) == want { $1 = ""; sub(/^[ \t]+/, ""); v = $0 }
    END { if (v == "") print "-"; else print v }'
}

# Redacted, size-capped excerpt of the body on stderr.
emit_body_excerpt() { # emit_body_excerpt <file> <bytes>
  local excerpt
  [[ "$2" -gt 0 ]] || return 0
  excerpt="$(head -c "${BODY_EXCERPT_BYTES}" "$1" | tr -d '\000')"
  redact "${excerpt}" >&2
  if [[ "$2" -gt "${BODY_EXCERPT_BYTES}" ]]; then
    echo "[body excerpt truncated to ${BODY_EXCERPT_BYTES} of $2 bytes]" >&2
  fi
}

# One-line JSON shape summary for --probe (top-level type, keys, data wrapper shape).
json_shape() {
  jq -r '
    def shape: if type == "array" then "array[\(length)]"
               elif type == "object" then "object{\(length)}"
               else type end;
    def keylist: (keys_unsorted | .[:8] | join(",")) + (if (keys | length) > 8 then ",..." else "" end);
    "json=\(shape)"
    + (if type == "object" then " top_keys=\(keylist)" else "" end)
    + (if type == "object" and (.data | type) == "object"
         then " data=\(.data | to_entries | .[:8] | map("\(.key):\(.value | shape)") | join(","))"
              + (if (.data | length) > 8 then ",..." else "" end)
       elif type == "object" and has("data") then " data=\(.data | shape)"
       else "" end)
  ' "$1" 2>/dev/null || true
}

# ---------- argument parsing ----------

PROBE=0
DRY_RUN=0
UNCHECKED=0
re_num='^[0-9]+$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --probe) PROBE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --unchecked) UNCHECKED=1 ;;
    --timeout) [[ $# -ge 2 ]] || die_usage "--timeout needs a value"; MAX_TIME="$2"; shift ;;
    --timeout=*) MAX_TIME="${1#*=}" ;;
    --connect-timeout) [[ $# -ge 2 ]] || die_usage "--connect-timeout needs a value"; CONNECT_TIMEOUT="$2"; shift ;;
    --connect-timeout=*) CONNECT_TIMEOUT="${1#*=}" ;;
    --) shift; break ;;
    -*) die_usage "unknown option '$1'" ;;
    *) break ;;
  esac
  shift
done

[[ "${MAX_TIME}" =~ ${re_num} ]] || die_usage "timeout must be a whole number of seconds"
[[ "${CONNECT_TIMEOUT}" =~ ${re_num} ]] || die_usage "connect timeout must be a whole number of seconds"

[[ $# -ge 1 ]] || die_usage "missing <endpoint>"
ENDPOINT="$1"; shift

SEGMENT=""
re_seg='^[0-9]{4}(-[0-9]{2}-[0-9]{2})?$'
re_date='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
re_year='^[0-9]{4}$'
if [[ $# -ge 1 && "$1" =~ ${re_seg} ]]; then
  SEGMENT="$1"; shift
fi

[[ $# -ge 1 ]] || die_usage "missing <SPORT>"
SPORT_RAW="$1"; shift

# ---------- validation ----------

re_endpoint='^[a-z][a-z0-9-]*$'
[[ "${ENDPOINT}" =~ ${re_endpoint} ]] || die_usage "invalid endpoint name '${ENDPOINT}'"

SHAPE="$(endpoint_shape "${ENDPOINT}")"
if [[ ${UNCHECKED} -eq 1 ]]; then
  SHAPE=any
elif [[ "${SHAPE}" == unknown ]]; then
  die_usage "unknown endpoint '${ENDPOINT}'. Documented endpoints: ${ENDPOINTS} (use --unchecked to probe others)"
fi

case "${SHAPE}" in
  date)
    [[ -n "${SEGMENT}" ]] || die_usage "${ENDPOINT} needs a date: df.sh ${ENDPOINT} <YYYY-MM-DD> <SPORT>"
    [[ "${SEGMENT}" =~ ${re_date} ]] || die_usage "${ENDPOINT} needs a full date (YYYY-MM-DD), got '${SEGMENT}'"
    ;;
  year-or-date)
    [[ -n "${SEGMENT}" ]] || die_usage "${ENDPOINT} needs a season year or date: df.sh ${ENDPOINT} <YYYY|YYYY-MM-DD> <SPORT>"
    ;;
  optional-year)
    if [[ -n "${SEGMENT}" && ! "${SEGMENT}" =~ ${re_year} ]]; then
      die_usage "${ENDPOINT} takes a season year (YYYY) or no segment, got '${SEGMENT}'"
    fi
    ;;
  none)
    [[ -z "${SEGMENT}" ]] || die_usage "${ENDPOINT} takes no date/season segment (got '${SEGMENT}'): df.sh ${ENDPOINT} <SPORT> [key=value ...]"
    ;;
  any) ;;
esac

SPORT="$(upper "${SPORT_RAW}")"
case "${SPORT}" in
  NCAA_BB|NCAA-BB|"NCAA BB") SPORT=NCAABB ;;
  NCAA_FB|NCAA-FB|"NCAA FB") SPORT=NCAAFB ;;
esac
re_sport='^[A-Z0-9_]+$'
[[ "${SPORT}" =~ ${re_sport} ]] || die_usage "invalid sport code '${SPORT_RAW}'"
if [[ ${UNCHECKED} -eq 0 ]]; then
  in_list "${SPORT}" "${SPORTS}" || die_usage "unknown sport '${SPORT_RAW}'. Supported: ${SPORTS} (use --unchecked to probe others)"
fi

DATA_ARGS=()
PARAM_QUERY=""
HAS_LEAGUE=0
LEAGUE=""
re_kv='^([A-Za-z][A-Za-z0-9_]*)=([A-Za-z0-9_.-]+)$'
for kv in "$@"; do
  case "${kv}" in
    -*) die_usage "unknown option '${kv}' (flags must come before <endpoint>)" ;;
  esac
  case "$(lower "${kv}")" in
    rsc_token|rsc_token=*) die_usage "never pass the token as a parameter; export RSC_TOKEN instead" ;;
    _=*) die_usage "'_' is the cache-buster and is added automatically" ;;
  esac
  [[ "${kv}" =~ ${re_kv} ]] || die_usage "bad parameter '${kv}': expected key=value with the value in [A-Za-z0-9_.-]+"
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  if [[ ${UNCHECKED} -eq 0 ]]; then
    in_list "${key}" "${PARAM_KEYS}" || die_usage "unknown parameter '${key}'. Supported: ${PARAM_KEYS} (use --unchecked to send others)"
  fi
  if [[ "${key}" == league ]]; then
    HAS_LEAGUE=1
    LEAGUE="${val}"
  fi
  PARAM_QUERY+="&${key}=${val}"
  DATA_ARGS+=(--data-urlencode "${key}=${val}")
done

if [[ ${UNCHECKED} -eq 0 && "${SPORT}" == SOCCER ]]; then
  [[ ${HAS_LEAGUE} -eq 1 ]] || die_usage "SOCCER requires league=EPL|LALIGA|SERIEA (omitting it returns a 404 URL-structure error)"
  in_list "${LEAGUE}" "${SOCCER_LEAGUES}" || die_usage "unknown soccer league '${LEAGUE}'. Supported: ${SOCCER_LEAGUES} (use --unchecked to probe others)"
fi

BASE_URL="${BASE_URL%/}"
re_https='^https://'
re_loopback='^http://(127\.0\.0\.1|localhost|\[::1\])(:[0-9]+)?(/|$)'
if [[ ! "${BASE_URL}" =~ ${re_https} ]]; then
  if [[ "${BASE_URL}" =~ ${re_loopback} || "${DF_ALLOW_INSECURE:-0}" == 1 ]]; then
    echo "df.sh: warning: base URL is not https; the token travels in cleartext" >&2
  else
    die_usage "ROLLING_INSIGHTS_BASE_URL must start with https:// (http:// is allowed only for loopback hosts, or with DF_ALLOW_INSECURE=1)"
  fi
fi

# ---------- request assembly (non-secret parts only) ----------

REQ_PATH="/${ENDPOINT}"
[[ -n "${SEGMENT}" ]] && REQ_PATH+="/${SEGMENT}"
REQ_PATH+="/${SPORT}"

# Cache buster: epoch seconds + 3 random digits. Portable (macOS/BSD and GNU date,
# bash 3.2); uniqueness is what matters, not sub-second precision.
BUSTER="$(date +%s)$(printf '%03d' $(( RANDOM % 1000 )))"
DATA_ARGS+=(--data-urlencode "_=${BUSTER}")

DISPLAY_URL="${BASE_URL}${REQ_PATH}?RSC_token=REDACTED${PARAM_QUERY}&_=${BUSTER}"
PROBE_REQUEST="${REQ_PATH}${PARAM_QUERY:+?${PARAM_QUERY#&}}"

if [[ ${DRY_RUN} -eq 1 ]]; then
  redact "${DISPLAY_URL}"
  exit "${EX_OK}"
fi

if [[ -z "${RSC_TOKEN:-}" ]]; then
  echo "Missing token: set RSC_TOKEN (30-day free trial: ${TRIAL_URL})" >&2
  exit "${EX_NO_TOKEN}"
fi
TOKEN_ENC_UPPER="$(urlencode "${RSC_TOKEN}" X)"
TOKEN_ENC_LOWER="$(urlencode "${RSC_TOKEN}" x)"

redact "${DISPLAY_URL}" >&2

# ---------- request ----------

TMP_BODY="$(mktemp)"
TMP_HEADERS="$(mktemp)"
TMP_CURL_ERR="$(mktemp)"
trap 'rm -f "${TMP_BODY}" "${TMP_HEADERS}" "${TMP_CURL_ERR}"' EXIT

CURL_RC=0
HTTP_CODE="$(curl -sS -G \
  --connect-timeout "${CONNECT_TIMEOUT}" --max-time "${MAX_TIME}" \
  -H 'Accept: application/json' \
  -H 'Cache-Control: no-cache, no-store' \
  -H 'Pragma: no-cache' \
  -D "${TMP_HEADERS}" -o "${TMP_BODY}" -w '%{http_code}' \
  --data-urlencode "RSC_token=${RSC_TOKEN}" \
  "${DATA_ARGS[@]}" \
  "${BASE_URL}${REQ_PATH}" 2>"${TMP_CURL_ERR}")" || CURL_RC=$?

re_code='^[0-9]{3}$'
[[ "${HTTP_CODE}" =~ ${re_code} ]] || HTTP_CODE=000
BYTES="$(wc -c < "${TMP_BODY}" | tr -d '[:space:]')"
CONTENT_TYPE="$(header_value "${TMP_HEADERS}" Content-Type)"
CONTENT_TYPE="${CONTENT_TYPE%%;*}"
CONTENT_TYPE="$(printf '%s' "${CONTENT_TYPE}" | sed 's/[[:space:]]*$//')"
CURL_MSG="$(head -c 2000 "${TMP_CURL_ERR}" | tr -d '\000')"
BODY_IS_JSON=0
if [[ "${BYTES}" -gt 0 ]] && jq . "${TMP_BODY}" >/dev/null 2>&1; then
  BODY_IS_JSON=1
fi

# ---------- classification ----------

CLASS=""
EXIT_CODE=0
if [[ ${CURL_RC} -eq 28 ]]; then
  CLASS=timeout; EXIT_CODE=${EX_TIMEOUT}
elif [[ ${CURL_RC} -ne 0 ]]; then
  CLASS=network; EXIT_CODE=${EX_NETWORK}
elif [[ "${HTTP_CODE}" == 304 ]]; then
  CLASS=not-modified; EXIT_CODE=${EX_NOT_MODIFIED}
elif [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
  CLASS=http-error; EXIT_CODE=${EX_HTTP_ERROR}
elif [[ "${BYTES}" -eq 0 ]]; then
  CLASS=non-json; EXIT_CODE=${EX_NON_JSON}
elif [[ ${BODY_IS_JSON} -eq 1 ]]; then
  CLASS=ok; EXIT_CODE=${EX_OK}
else
  FIRST_CHAR="$(head -c 512 "${TMP_BODY}" | tr -d ' \t\r\n' | cut -c1)"
  if [[ "${CONTENT_TYPE}" == *json* || "${FIRST_CHAR}" == "{" || "${FIRST_CHAR}" == "[" ]]; then
    CLASS=malformed-json; EXIT_CODE=${EX_MALFORMED_JSON}
  else
    CLASS=non-json; EXIT_CODE=${EX_NON_JSON}
  fi
fi

# ---------- diagnostics (stderr, always redacted) ----------

case "${CLASS}" in
  timeout)
    [[ -n "${CURL_MSG}" ]] && redact "${CURL_MSG}" >&2
    echo "Timeout: no complete response within ${MAX_TIME}s total / ${CONNECT_TIMEOUT}s connect (curl exit 28, HTTP code ${HTTP_CODE})" >&2
    ;;
  network)
    [[ -n "${CURL_MSG}" ]] && redact "${CURL_MSG}" >&2
    echo "Network failure: transfer did not complete (curl exit ${CURL_RC}, HTTP code ${HTTP_CODE})" >&2
    ;;
  not-modified)
    echo "304 Not Modified: no body returned; see references/troubleshooting.md (304 responses)" >&2
    ;;
  http-error)
    emit_body_excerpt "${TMP_BODY}" "${BYTES}"
    if [[ "${HTTP_CODE}" -ge 300 && "${HTTP_CODE}" -lt 400 ]]; then
      redact "Location: $(header_value "${TMP_HEADERS}" Location)" >&2
      echo "HTTP error ${HTTP_CODE} (redirect not followed; ${CONTENT_TYPE}, ${BYTES} bytes)" >&2
    elif [[ ${BODY_IS_JSON} -eq 1 ]]; then
      echo "HTTP error ${HTTP_CODE} (JSON body, ${CONTENT_TYPE}, ${BYTES} bytes)" >&2
    else
      echo "HTTP error ${HTTP_CODE} (non-JSON body, ${CONTENT_TYPE}, ${BYTES} bytes)" >&2
    fi
    ;;
  non-json)
    emit_body_excerpt "${TMP_BODY}" "${BYTES}"
    if [[ "${BYTES}" -eq 0 ]]; then
      echo "Non-JSON response: HTTP ${HTTP_CODE} with an empty body (${CONTENT_TYPE})" >&2
    else
      echo "Non-JSON response: HTTP ${HTTP_CODE}, ${CONTENT_TYPE}, ${BYTES} bytes" >&2
    fi
    ;;
  malformed-json)
    emit_body_excerpt "${TMP_BODY}" "${BYTES}"
    echo "Malformed JSON response: HTTP ${HTTP_CODE}, ${CONTENT_TYPE}, ${BYTES} bytes (looks like JSON but does not parse)" >&2
    ;;
esac

# ---------- output ----------

if [[ ${PROBE} -eq 1 ]]; then
  SUMMARY="http=${HTTP_CODE} class=${CLASS} curl=${CURL_RC} bytes=${BYTES} content_type=${CONTENT_TYPE} request=${PROBE_REQUEST}"
  if [[ ${BODY_IS_JSON} -eq 1 ]]; then
    SUMMARY+=" $(json_shape "${TMP_BODY}")"
  fi
  redact "${SUMMARY}"
elif [[ "${CLASS}" == ok ]]; then
  cat "${TMP_BODY}"
fi

exit "${EXIT_CODE}"
