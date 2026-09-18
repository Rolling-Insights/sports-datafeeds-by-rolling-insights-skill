#!/usr/bin/env bash
# df.sh: the one safe way to call the DataFeeds by Rolling Insights REST API from a shell.
#
#   scripts/df.sh [flags] '<url>'
#
# <url> is the full request URL without the token, exactly what a customer's code
# would call; a bare path starting with "/" is prefixed with the base URL. Run with
# --help for the flags, the output modes and the exit-code table.
#
# The runner holds no endpoint knowledge (no endpoint, sport or parameter lists: the
# spec owns those). It pins the host, appends the token outside the transcript,
# classifies the outcome, redacts, and writes the body to a file with a summary line.
#
# Token safety (public repo, query-string credential):
#   * the token is read from RSC_TOKEN only and handed to curl via --data-urlencode,
#     so it is never interpolated into a URL string;
#   * the stderr request echo is assembled from non-secret parts with a literal
#     "RSC_token=REDACTED";
#   * every other diagnostic line (curl messages, response headers, error-body
#     excerpts, the output file name, the summary line) passes through redact(), a
#     literal, non-pattern replacement of the raw token and every percent-encoded
#     form curl builds produce (upper/lower hex, space as "+" or "%20", "~" kept or
#     encoded) so an echoed query cannot leak it.
# Keep all three intact when changing this file.
set -euo pipefail

API_HOST="rest.datafeeds.rolling-insights.com"
DEFAULT_BASE_URL="https://${API_HOST}/api/v1"
BASE_URL="${ROLLING_INSIGHTS_BASE_URL:-${DEFAULT_BASE_URL}}"
OUT_DIR="./df-out"
CONNECT_TIMEOUT="${DF_CONNECT_TIMEOUT:-10}"
MAX_TIME="${DF_TIMEOUT:-60}"
BODY_EXCERPT_BYTES=4096
SLUG_MAX=80
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

usage() {
  cat <<'USAGE'
Usage: df.sh [flags] '<url>'

The one safe way to call the DataFeeds REST API from a shell. <url> is the full
request URL without the token, exactly what a customer's code would call:

  df.sh 'https://rest.datafeeds.rolling-insights.com/api/v1/team-stats/2025/SOCCER?league=EPL'
  df.sh --stdout 'https://rest.datafeeds.rolling-insights.com/api/v1/schedule/2026-09-18/NBA'
  df.sh '/schedule/2026-09-18/NBA'      (a bare path is prefixed with the base URL)

The runner reads the token from RSC_TOKEN and appends it to the query itself (never
put RSC_token= in the URL), pins the host, prints a redacted request line to stderr,
classifies the outcome, and by default writes the body to a file,

  ./df-out/<path-slug>-<UTC timestamp>.json

with one summary line on stdout:

  http=200 class=ok bytes=... content_type=... file=... json=object{1} keys=data data=NBA:array[12]

keys= lists the top-level keys; data= describes the shape under a "data" key
(key:shape pairs for a keyed map, array[N] for an array). Nothing from the body's
values is printed. Read the file with jq when you need the data.

Flags:
  --stdout             Print the body on stdout instead of writing a file (small payloads).
  --out <path>         Write the body to <path> instead of the default file.
  --dry-run            Print the redacted request line and exit 0. No token, no network.
  --timeout N          Total request timeout in seconds (default 60; env DF_TIMEOUT).
  --connect-timeout N  Connect timeout in seconds (default 10; env DF_CONNECT_TIMEOUT).
  -h, --help           This text.

Environment:
  RSC_TOKEN                  API token (required unless --dry-run / --help).
  ROLLING_INSIGHTS_BASE_URL  Base URL for bare paths; its host is also accepted
                             (default https://rest.datafeeds.rolling-insights.com/api/v1).
  DF_ALLOW_INSECURE=1        Accept a loopback host (127.0.0.1, localhost, [::1]) for a
                             local mock server. The only way a non-https URL is accepted.
  DF_TIMEOUT, DF_CONNECT_TIMEOUT   See --timeout / --connect-timeout.

Refused before any request (exit 2): a URL that is not https:// on the DataFeeds host
(or the host of ROLLING_INSIGHTS_BASE_URL); a URL that already contains RSC_token=;
extra arguments. Redirects are never followed.

Exit codes (each outcome is reported distinctly on stderr):
  0  HTTP 2xx with valid JSON (body in the file, or on stdout with --stdout)
  2  usage error or refused URL
  3  missing token
  4  network failure (curl could not complete the transfer; HTTP code 000)
  5  timeout (connect or total)
  6  HTTP 304 Not Modified (no body; a cache problem, not data)
  7  HTTP error: 4xx / 5xx, or a redirect that was not followed (body excerpt on stderr)
  8  HTTP 2xx but the body is not JSON (empty, plain text, HTML)
  9  HTTP 2xx and the body looks like JSON but does not parse
USAGE
}

# ---------- helpers ----------

# Literal (non-pattern) replacement of the token in a string: the raw value and
# every percent-encoded form a curl build may put on the wire (TOKEN_ENCODINGS,
# filled once the token is known). The quoted pattern in ${s//"..."/} disables glob
# matching (bash >= 3.2), so the token is opaque data.
TOKEN_ENCODINGS=()
redact() {
  local s="$1" enc
  if [[ -n "${RSC_TOKEN:-}" ]]; then
    s="${s//"${RSC_TOKEN}"/REDACTED}"
    for enc in ${TOKEN_ENCODINGS[@]+"${TOKEN_ENCODINGS[@]}"}; do
      if [[ -n "${enc}" && "${enc}" != "${RSC_TOKEN}" ]]; then
        s="${s//"${enc}"/REDACTED}"
      fi
    done
  fi
  printf '%s\n' "${s}"
}

# Percent-encode like curl --data-urlencode. Builds differ, so the variant is
# selectable: hex case (X or x), space as "+" (curl's form encoding, verified on
# curl 8.7) or "%20", and "~" kept (curl >= 7.72) or encoded as %7E (older builds).
urlencode() { # urlencode <string> <X|x> <plus|pct> <keep|enc>
  local s="$1" fmt="%%%02${2:-X}" space="${3:-plus}" tilde="${4:-keep}" out="" i c
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "${c}" in
      [A-Za-z0-9._-]) out+="${c}" ;;
      '~') if [[ "${tilde}" == keep ]]; then out+="${c}"; else out+="$(printf "${fmt}" "'${c}")"; fi ;;
      ' ') if [[ "${space}" == plus ]]; then out+="+"; else out+="$(printf "${fmt}" "'${c}")"; fi ;;
      *) out+="$(printf "${fmt}" "'${c}")" ;;
    esac
  done
  printf '%s' "${out}"
}

# Every encoded form of the token that redact() must recognise.
token_encodings() {
  local hexcase space tilde
  for hexcase in X x; do
    for space in plus pct; do
      for tilde in keep enc; do
        TOKEN_ENCODINGS+=("$(urlencode "${RSC_TOKEN}" "${hexcase}" "${space}" "${tilde}")")
      done
    done
  done
}

die_usage() {
  redact "df.sh: $*" >&2
  echo "Run 'df.sh --help' for usage." >&2
  exit "${EX_USAGE}"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

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

# JSON shape for the summary line: top-level type, top-level keys, shape under "data".
# Key names and container sizes only, never values.
json_shape() {
  jq -r '
    def shape: if type == "array" then "array[\(length)]"
               elif type == "object" then "object{\(length)}"
               else type end;
    def keylist: (keys_unsorted | .[:8] | join(",")) + (if (keys | length) > 8 then ",..." else "" end);
    "json=\(shape)"
    + (if type == "object" then " keys=\(keylist)" else "" end)
    + (if type == "object" and (.data | type) == "object"
         then " data=\(.data | to_entries | .[:8] | map("\(.key):\(.value | shape)") | join(","))"
              + (if (.data | length) > 8 then ",..." else "" end)
       elif type == "object" and has("data") then " data=\(.data | shape)"
       else "" end)
  ' "$1" 2>/dev/null || true
}

# ---------- argument parsing ----------

STDOUT_MODE=0
DRY_RUN=0
OUT_PATH=""
re_num='^[0-9]+$'

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --stdout) STDOUT_MODE=1 ;;
    --out) [[ $# -ge 2 ]] || die_usage "--out needs a path"; OUT_PATH="$2"; shift ;;
    --out=*) OUT_PATH="${1#*=}" ;;
    --dry-run) DRY_RUN=1 ;;
    --timeout) [[ $# -ge 2 ]] || die_usage "--timeout needs a value"; MAX_TIME="$2"; shift ;;
    --timeout=*) MAX_TIME="${1#*=}" ;;
    --connect-timeout) [[ $# -ge 2 ]] || die_usage "--connect-timeout needs a value"; CONNECT_TIMEOUT="$2"; shift ;;
    --connect-timeout=*) CONNECT_TIMEOUT="${1#*=}" ;;
    --probe) die_usage "--probe was retired: the summary line is now the default output; use --stdout for the body" ;;
    --unchecked) die_usage "--unchecked was retired: the runner no longer validates endpoints, sports or parameters" ;;
    --) shift; break ;;
    -*)
      case "$(lower "$1")" in
        *rsc_token*) die_usage "unknown option (its text contains RSC_token, so it is not shown); export RSC_TOKEN instead" ;;
        *) die_usage "unknown option '$1'" ;;
      esac ;;
    *) break ;;
  esac
  shift
done

[[ "${MAX_TIME}" =~ ${re_num} ]] || die_usage "timeout must be a whole number of seconds"
[[ "${CONNECT_TIMEOUT}" =~ ${re_num} ]] || die_usage "connect timeout must be a whole number of seconds"

[[ $# -ge 1 && -n "$1" ]] || die_usage "missing <url>: df.sh [flags] '<url>'"
URL_ARG="$1"; shift
[[ $# -eq 0 ]] || die_usage "unexpected extra argument(s) after the URL: the runner takes exactly one full URL (no positional endpoint/date/sport, no key=value parameters)"

# Refuse a token in the URL before anything echoes the URL. The message never
# includes the URL, so the value cannot leak even if it differs from RSC_TOKEN.
case "$(lower "${URL_ARG}")" in
  *rsc_token*) die_usage "the URL already contains RSC_token; remove it and export RSC_TOKEN instead (the runner appends the token itself)" ;;
esac

# ---------- URL intake and host pinning ----------

BASE_URL="${BASE_URL%/}"
re_url='^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$'
[[ "${BASE_URL}" =~ ${re_url} ]] || die_usage "ROLLING_INSIGHTS_BASE_URL is not a URL: $(redact "${BASE_URL}")"
BASE_HOST="$(lower "${BASH_REMATCH[2]}")"
BASE_PATH="${BASH_REMATCH[3]:-}"

if [[ "${URL_ARG}" == /* ]]; then
  URL="${BASE_URL}${URL_ARG}"
else
  URL="${URL_ARG}"
fi

[[ "${URL}" =~ ${re_url} ]] || die_usage "not a URL: expected https://<host>/<path>[?query] or a bare /path, got '${URL_ARG}'"
SCHEME="$(lower "${BASH_REMATCH[1]}")"
AUTHORITY="$(lower "${BASH_REMATCH[2]}")"
URL_PATH="${BASH_REMATCH[3]:-}"
URL_QUERY="${BASH_REMATCH[4]:-}"
URL_FRAGMENT="${BASH_REMATCH[5]:-}"

[[ -z "${URL_FRAGMENT}" ]] || die_usage "the URL has a fragment (#...), which is never sent; remove it"
[[ -n "${AUTHORITY}" ]] || die_usage "the URL has no host"
case "${AUTHORITY}" in
  *@*) die_usage "the URL carries userinfo (user@host), which is refused because it can disguise the real host" ;;
esac
[[ "${SCHEME}" == https ]] && AUTHORITY="${AUTHORITY%:443}"

re_loopback='^(127\.0\.0\.1|localhost|\[::1\])(:[0-9]+)?$'
if [[ "${SCHEME}" == https && ( "${AUTHORITY}" == "${API_HOST}" || "${AUTHORITY}" == "${BASE_HOST}" ) ]]; then
  :
elif [[ "${AUTHORITY}" =~ ${re_loopback} && "${DF_ALLOW_INSECURE:-0}" == 1 ]]; then
  if [[ "${SCHEME}" != https ]]; then
    echo "df.sh: warning: loopback URL is not https; the token travels in cleartext (DF_ALLOW_INSECURE=1)" >&2
  fi
else
  die_usage "refused ${SCHEME}://${AUTHORITY}: the token is only sent over https to ${API_HOST} (or the host of ROLLING_INSIGHTS_BASE_URL); loopback hosts need DF_ALLOW_INSECURE=1"
fi

# ---------- request assembly (non-secret parts only) ----------

# Cache buster: epoch seconds + 3 random digits. Portable (macOS/BSD and GNU date,
# bash 3.2); uniqueness is what matters, not sub-second precision.
BUSTER="$(date +%s)$(printf '%03d' $(( RANDOM % 1000 )))"

case "${URL_QUERY}" in
  "")  SEP="?" ;;
  "?") SEP="" ;;
  *)   SEP="&" ;;
esac
DISPLAY_URL="${URL}${SEP}RSC_token=REDACTED&_=${BUSTER}"

if [[ ${DRY_RUN} -eq 1 ]]; then
  redact "${DISPLAY_URL}"
  exit "${EX_OK}"
fi

if [[ -z "${RSC_TOKEN:-}" ]]; then
  echo "Missing token: set RSC_TOKEN (30-day free trial: ${TRIAL_URL})" >&2
  exit "${EX_NO_TOKEN}"
fi
token_encodings

# ---------- output file name (decided before the request so a bad path fails early) ----------

OUT_FILE=""
DISPLAY_FILE="-"
if [[ ${STDOUT_MODE} -eq 0 ]]; then
  if [[ -n "${OUT_PATH}" ]]; then
    OUT_FILE="${OUT_PATH}"
  else
    SLUG_SRC="${URL_PATH}"
    if [[ -n "${BASE_PATH}" && "${SLUG_SRC}" == "${BASE_PATH}/"* ]]; then
      SLUG_SRC="${SLUG_SRC#"${BASE_PATH}"}"
    fi
    SLUG_SRC+="${URL_QUERY}"
    SLUG="$(printf '%s' "${SLUG_SRC}" | LC_ALL=C sed -e 's/[^A-Za-z0-9._-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
    SLUG="${SLUG:0:${SLUG_MAX}}"
    [[ -n "${SLUG}" ]] || SLUG="request"
    SLUG="$(redact "${SLUG}")"
    STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT_FILE="${OUT_DIR}/${SLUG}-${STAMP}.json"
    n=1
    while [[ -e "${OUT_FILE}" ]]; do
      OUT_FILE="${OUT_DIR}/${SLUG}-${STAMP}-${n}.json"
      n=$(( n + 1 ))
    done
  fi
  DISPLAY_FILE="$(redact "${OUT_FILE}")"
  OUT_PARENT="$(dirname "${OUT_FILE}")"
  mkdir -p "${OUT_PARENT}" 2>/dev/null || die_usage "cannot create the output directory '${OUT_PARENT}'"
  [[ -w "${OUT_PARENT}" ]] || die_usage "the output directory '${OUT_PARENT}' is not writable"
fi

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
  --data-urlencode "_=${BUSTER}" \
  "${URL}" 2>"${TMP_CURL_ERR}")" || CURL_RC=$?

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
    echo "304 Not Modified: no body returned (a cache problem, not data)" >&2
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

if [[ ${STDOUT_MODE} -eq 1 ]]; then
  [[ "${CLASS}" == ok ]] && cat "${TMP_BODY}"
else
  FILE_FIELD="-"
  if [[ "${CLASS}" == ok ]]; then
    if cp "${TMP_BODY}" "${OUT_FILE}" 2>/dev/null; then
      FILE_FIELD="${DISPLAY_FILE}"
    else
      echo "df.sh: could not write the body to ${DISPLAY_FILE}" >&2
      EXIT_CODE=${EX_USAGE}
    fi
  fi
  SUMMARY="http=${HTTP_CODE} class=${CLASS} bytes=${BYTES} content_type=${CONTENT_TYPE} file=${FILE_FIELD}"
  if [[ ${BODY_IS_JSON} -eq 1 ]]; then
    SUMMARY+=" $(json_shape "${TMP_BODY}")"
  fi
  redact "${SUMMARY}"
fi

exit "${EXIT_CODE}"
