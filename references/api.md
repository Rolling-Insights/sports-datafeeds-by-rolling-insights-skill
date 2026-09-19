# The REST API

## Base URL and authentication

```text
https://rest.datafeeds.rolling-insights.com/api/v1
```

Every request carries the token as the `RSC_token` query parameter. Obtain one at the API Locker;
new accounts include a 30-day free trial:

```text
https://accounts.rolling-insights.com/register
```

Read the token from the `RSC_TOKEN` environment variable. It is the only supported variable name;
the query parameter is always `RSC_token`.

```bash
export RSC_TOKEN='your-token'
```

The base URL can be overridden for the runner with `ROLLING_INSIGHTS_BASE_URL`; customer code
targets the URL above.

### Security rules for a query-string credential

The token travels in the URL, so it leaks through server logs, browser history, proxies, referrer
headers, error traces, screenshots and copy-paste. Treat it as a long-lived secret:

- **HTTPS only.** Never `http://`; the runner refuses it.
- **Store it in `RSC_TOKEN`** (environment or secret store). Do not commit it, embed it in source,
  paste it into prompts or notebooks, or write it into a chat transcript.
- **Never share or display a raw request URL.** Not in chats, tickets, issue trackers, logs,
  screenshots or browser history. The runner redacts the token from everything it prints; keep that
  property in anything adapted from it.
- **Rotate immediately on suspected exposure**, at the API Locker, before continuing.
- **Never ask a user to paste a token.** Point to `export RSC_TOKEN=...` in their own shell.

## The runner: `scripts/df.sh`

The one safe way to call the API from a shell. It takes the full request URL without the token,
exactly what a customer's code would call, and adds the rest: reads `RSC_TOKEN`, sends it
URL-encoded over HTTPS to `rest.datafeeds.rolling-insights.com` only (any other host is refused
before a request is made), adds `Cache-Control: no-cache, no-store`, `Pragma: no-cache` and a
timestamp cache buster, classifies the outcome, redacts, and writes the body to a file with one
summary line. It holds no endpoint knowledge: build the URL from the spec.

```bash
# Default: body to ./df-out/<path-slug>-<UTC timestamp>.json, one summary line on stdout
scripts/df.sh 'https://rest.datafeeds.rolling-insights.com/api/v1/schedule/<YYYY-MM-DD>/NBA'

# A bare path is prefixed with the base URL
scripts/df.sh '/team-stats/<YYYY>/SOCCER?league=EPL'

# Small payload: print the body on stdout instead of writing a file
scripts/df.sh --stdout '/live/<YYYY-MM-DD>/NBA'

# Choose the output file
scripts/df.sh --out nba-schedule.json '/schedule/<YYYY-MM-DD>/NBA'

# Print the redacted request line and exit: no token read, no request made
scripts/df.sh --dry-run '/play-by-play/MLB?game_id=<game_ID>'

# Full usage and the exit-code table
scripts/df.sh --help
```

The summary line:

```text
http=200 class=ok bytes=<n> content_type=application/json file=./df-out/schedule-<date>-NBA-<stamp>.json json=object{1} keys=data data=NBA:array[<n>]
```

`keys=` lists the top-level keys; `data=` describes the shape under `data` (key:shape pairs for a
keyed map, `array[N]` for an array). Nothing from the body's values is printed. Read the file with
`jq`; never print it whole.

Refused before any request (exit 2): a URL that is not `https://` on the DataFeeds host (or the
host of `ROLLING_INSIGHTS_BASE_URL`); a URL that already contains `RSC_token=`; userinfo
(`user@host`); a fragment; extra arguments. Redirects are never followed. A loopback host is
accepted only with `DF_ALLOW_INSECURE=1`, for a local mock server.

Flags: `--stdout`, `--out <path>`, `--dry-run`, `--timeout N` (default 60; env `DF_TIMEOUT`),
`--connect-timeout N` (default 10; env `DF_CONNECT_TIMEOUT`), `-h` / `--help`.

Exit codes, each reported distinctly on stderr:

| Exit | Class | Meaning |
| --- | --- | --- |
| 0 | `ok` | HTTP 2xx with valid JSON; body in the file, or on stdout with `--stdout` |
| 2 | usage | usage error or refused URL; no request was made |
| 3 | no token | `RSC_TOKEN` is unset; no request was made |
| 4 | `network` | curl could not complete the transfer (HTTP code 000) |
| 5 | `timeout` | connect or total timeout |
| 6 | `not-modified` | HTTP 304, no body |
| 7 | `http-error` | 4xx / 5xx, or a redirect that was not followed; redacted body excerpt on stderr |
| 8 | `non-json` | HTTP 2xx but the body is empty, plain text or HTML; excerpt on stderr |
| 9 | `malformed-json` | HTTP 2xx, looks like JSON, does not parse |

Report the class to the user. Never treat a 304, an HTTP error, or a non-JSON body as data.

## The spec

The REST contract lives in one public file (no token needed, about 800 KB, 84 routes):

```text
https://docs.datafeeds.rolling-insights.com/spec.json
```

### The three commands

```bash
curl -s https://docs.datafeeds.rolling-insights.com/spec.json -o /tmp/spec.json
jq '.paths | keys' /tmp/spec.json
jq -f scripts/route.jq --arg path '/live/{date}/NBA' /tmp/spec.json
```

Note the date you downloaded it; the spec carries no per-deploy version.

`scripts/route.jq` ships with this skill (path relative to the skill directory; jq 1.6 or later,
nothing else). It prints one object: `path`, `summary`, `description`, `parameters` (name, `in`,
required, description, schema with enums) and `response`, the 200 JSON schema with every `$ref`
resolved. Redirect it to a file (`> /tmp/route.json`) when the schema is big; the largest live
box-score route is about 37 KB.

### Pick the route before resolving it

Read a candidate's summary and description first; resolve only the one you will call:

```bash
jq --arg p '/live/{date}/NBA' '.paths[$p].get | {summary, description}' /tmp/spec.json
```

An unknown path fails with the closest matching paths on stderr. Paths are matched as written in
the spec, braces included (a case-insensitive match is tried second).

### Two rules

1. Never read the whole file into context. List the paths, read one route's summary and
   description, resolve that one route.
2. The MCP's tool names, arguments and responses say nothing about the REST contract. Only the
   spec does.

### Without a shell

Fetch the spec URL directly. `paths` is the route list; each route's `get` object holds
`summary`, `description`, `parameters` and `responses["200"]`; follow every `$ref` into
`components.schemas` by hand. Call the API in whatever way the environment allows, with the token
from the environment and never typed into the conversation. Code written this way is handed over
marked untested against the live API, with the one-line check the user can run.

## Troubleshooting

By HTTP status (the runner's exit code in brackets); the MCP shows the same statuses as texts,
listed in `references/mcp.md`.

| Signal | Meaning | Do |
| --- | --- | --- |
| 401 [7] | The token is wrong or expired. | Check `RSC_TOKEN` is set in the shell that runs the command (`[ -n "$RSC_TOKEN" ] && echo set`). Never print it. Rotate at the API Locker if it may have leaked. |
| 403 [7] | The token is valid; the plan does not cover that sport or resource. | Say so, offer a covered sport, point to the API Locker for the plan. |
| 304 [6] | No body. The API answers 304 when there is nothing to return: an off-day or off-season date, a season it does not serve, a season-less stats form it does not serve for that sport, an unrecognised `league` value. | Not a cache problem of the caller's making: the runner already sends no-cache headers and a fresh buster. Check the date (the league's game day, see `references/data-model.md`), the season (start year) and the league against the spec. Retry once if the request should have data. |
| 404 [7] | Wrong path or parameters; for soccer, a missing `league` returns a URL-structure error. | Rule 3: list the routes, resolve the one you mean. |
| 5xx [7] | Upstream error. | Report the status and the redacted excerpt. Retry once later. |
| 2xx, `data` empty or the sport key absent [0] | A valid answer with no rows. | Report "no rows", not an error; check date, season and league as for 304. |
| 2xx, non-JSON [8] or malformed [9] | The API answered with text or HTML, or broken JSON. | Read the excerpt on stderr; check the path and the date format against the resolved `parameters`. |
| exit 3 | `RSC_TOKEN` unset. | Point to `export RSC_TOKEN='your-token'` and the API Locker. Hand over work marked untested. |
| exit 4 / 5 | Network failure or timeout: no HTTP answer. | Distinguish it from a token or data problem; say the request did not complete. `--dry-run` still works without network. |

Final checks before reporting a failure: the token is set (not printed), the path is one the spec
lists, the date is `YYYY-MM-DD`, the season is the start year, soccer has `league`.

## GraphQL

DataFeeds also offers a GraphQL API with separate OAuth2 client-credentials authentication; the
spec's introduction links its sandbox. This skill covers the REST API and the MCP only.
