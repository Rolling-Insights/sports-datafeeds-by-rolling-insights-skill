# DataFeeds by Rolling Insights: AI Skill for Sports Data

Connect AI agents and developer tools to live scores, player stats, schedules, injuries, depth charts, play-by-play, and more across 9 sports leagues.

This repository contains the skill instructions, reference material, and helper scripts for using DataFeeds by Rolling Insights from AI agents and developer tools like Claude Code, Cursor, and Codex. The skill teaches an agent five rules: answer questions through the DataFeeds MCP server, write code against the REST API, start every REST task from the published OpenAPI spec, never assume a request or response structure, and evaluate every relevant route before choosing one.

A fully functional 30-day free trial is available at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register). No credit card required.

## What you can build

- **Fantasy sports agents** that pull injury reports, compare player stats, and surface DraftKings fantasy points across NFL, NBA, and MLB
- **Live scoreboard bots** that post real-time scores, box scores, and quarter-by-quarter updates to Discord, Slack, or a web app
- **AI recap generators** that use play-by-play and stat data to produce game summaries and player performance breakdowns
- **Sports LLM pipelines** that feed historical game and player data to custom models for projection, prediction, and DFS optimization

## Supported sports

The API sport codes, as written in REST paths:

- `NHL`
- `NBA`
- `NFL`
- `MLB`
- `NCAABB`
- `NCAAFB`
- `SOCCER` with `league=EPL`, `league=LALIGA`, or `league=SERIEA`
- `DARTS`
- `PGA`

Endpoint availability and payload shapes differ by sport. The published OpenAPI spec is the inventory (84 routes, no token needed): [docs.datafeeds.rolling-insights.com/spec.json](https://docs.datafeeds.rolling-insights.com/spec.json). The skill resolves one route at a time from it rather than carrying a hand-written endpoint list.

## Two ways to connect

- **MCP server**, for agents that answer questions with data: the agent gets a set of DataFeeds tools (`get_schedule`, `get_live`, `get_team_stats`, ...) and the token stays in the agent's client configuration. Setup for Claude Code, Cursor, and Codex: [docs.datafeeds.rolling-insights.com/agent-setup](https://docs.datafeeds.rolling-insights.com/agent-setup/).
- **REST API**, for code: `https://rest.datafeeds.rolling-insights.com/api/v1` with the `RSC_token` query parameter, read from the `RSC_TOKEN` environment variable.

The skill routes a request for data to the MCP when its tools are present, and every request for code to the REST API and the spec.

## Install as an agent skill

Install this repository as an agent skill with the [`skills` CLI](https://skills.sh). The CLI requires Node.js >= 22.20.0; on older versions npm reports `EBADENGINE` before anything installs.

```bash
npx skills add Rolling-Insights/sports-datafeeds-by-rolling-insights-skill
```

Run without flags, the CLI asks which of your installed agents to target. To install non-interactively for a specific agent:

```bash
# Claude Code (project-level) -> ./.claude/skills/datafeeds-sports-api
npx skills add Rolling-Insights/sports-datafeeds-by-rolling-insights-skill -a claude-code -y

# Cursor -> ./.agents/skills/datafeeds-sports-api
npx skills add Rolling-Insights/sports-datafeeds-by-rolling-insights-skill -a cursor -y
```

Add `-g` to install at the user level instead of into the current project (Claude Code: `~/.claude/skills/datafeeds-sports-api`).

The install directory is named from the skill's frontmatter `name` (`datafeeds-sports-api`), not from the repository name.

### Manual install (Claude Code)

Clone the repository directly into your personal skills directory:

```bash
git clone https://github.com/Rolling-Insights/sports-datafeeds-by-rolling-insights-skill.git ~/.claude/skills/datafeeds-sports-api
```

### After installing

For answers, connect the MCP server through the [agent setup guide](https://docs.datafeeds.rolling-insights.com/agent-setup/). For code and for the bundled runner, the skill reads your API token from the `RSC_TOKEN` environment variable; see the [Quick start](#quick-start) below. Use a placeholder such as `your-token` in anything you commit or share; never a real token.

## Quick start

### 1. Get a free trial token

Register at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register) for a 30-day fully functional API key. Standard pricing starts at $100/month after the trial. If you are building a sports-tech startup or MVP, [Breakaway Accelerator](https://rolling-insights.com/breakaway-accelerator/) offers discounted access starting at $60/month.

### 2. Set your token

```bash
export RSC_TOKEN='your-token'
```

Never hardcode real tokens in scripts, examples, prompts, or committed files.

### 3. Find the route in the spec

```bash
curl -s https://docs.datafeeds.rolling-insights.com/spec.json -o /tmp/spec.json
jq '.paths | keys' /tmp/spec.json
jq -f scripts/route.jq --arg path '/schedule/{date}/NBA' /tmp/spec.json
```

The third command prints the route's parameters and its response schema with every reference resolved.

### 4. Make your first request

```bash
# NBA schedule for a date: body to ./df-out/<path-slug>-<timestamp>.json, one summary line on stdout
./scripts/df.sh 'https://rest.datafeeds.rolling-insights.com/api/v1/schedule/2026-05-20/NBA'

# Live scores and box data for the same date, body inline
./scripts/df.sh --stdout 'https://rest.datafeeds.rolling-insights.com/api/v1/live/2026-05-20/NBA'
```

The runner reads your token from `RSC_TOKEN` and appends it to the request itself, prints a redacted URL to stderr, and writes the JSON body to a file (or to stdout with `--stdout`). See [`references/api.md`](references/api.md) for the flags, the exit codes, and troubleshooting by status code.

## What is included

- `SKILL.md`: the five rules, each written as a procedure with its trigger, its numbered steps, the exact commands, and a short Don't list; the availability policy; token handling
- `references/mcp.md`: the MCP setup pointer, the tool inventory and argument conventions, the limits, and the error texts the MCP returns with what to do for each
- `references/api.md`: base URL, authentication and token safety, the runner, the spec commands, and troubleshooting by status code and runner exit code
- `references/data-model.md`: what the spec cannot say, verified against the live API: identifiers and joins across routes, date and season semantics, and the empty-slate behaviour
- `scripts/df.sh`: the request runner; takes a full request URL, pins the host, appends the token, classifies the outcome, and writes the body to a file with a one-line summary
- `scripts/route.jq`: a jq filter that resolves one route of the spec (parameters and response schema, every `$ref` expanded)
- `tests/route-test.sh`: a synthetic-fixture check for the route filter

## The five rules

1. **MCP for questions.** DataFeeds MCP tools in the session answer requests for data; no scripts, no URLs, no token in chat. Tools absent: one setup pointer, then the REST path.
2. **REST for code.** Code targets the REST API, reads `RSC_TOKEN` at run time, never logs a full URL, and never embeds an MCP call.
3. **Spec first.** Every REST task starts from the published spec: list the routes, resolve the one you mean.
4. **No assumed structure.** Parsers are written against the resolved schema, and, when a token is set, checked against one real response captured by the runner before hand-over.
5. **Evaluate every route.** Read each candidate's summary and description, resolve the finalists, and state the choice in one line before calling.

## Authentication

DataFeeds REST requests require a query-string token named `RSC_token`.

Set the token in the supported environment variable:

```bash
export RSC_TOKEN='your-token'
```

You can also override the REST base URL for the runner when needed:

```bash
export ROLLING_INSIGHTS_BASE_URL='https://rest.datafeeds.rolling-insights.com/api/v1'
```

Never hardcode real tokens in scripts, examples, prompts, or committed files.

### Security note

`RSC_token` travels in the URL query string, so it can easily leak through logs, browser history, proxies, referrer headers, screenshots, and copy/paste. Treat it as a long-lived secret:

- **HTTPS only.** Always call `https://rest.datafeeds.rolling-insights.com/api/v1`; never downgrade to `http://`.
- **Keep `RSC_TOKEN` in env vars or a secret store.** Do not commit it, paste it into prompts, or write it into chat transcripts.
- **Do not share raw request URLs.** Avoid pasting full `RSC_token=...` URLs into chats, tickets, logs, screenshots, or browser history. The bundled runner redacts the token from everything it prints.
- **Rotate on suspected exposure.** If the token may have appeared in any of the channels above, rotate it via the API Locker before continuing.

For the MCP server the token is a bearer header held in the agent's client configuration by reference to `RSC_TOKEN`; the [agent setup guide](https://docs.datafeeds.rolling-insights.com/agent-setup/) is the only place that explains how. See [`references/api.md`](references/api.md) for the full credential-handling guidance.

## Helper scripts

`scripts/df.sh` is the one safe way to call the REST API from a shell. It takes the full request URL without the token, exactly what your own code would call, and adds the rest: it refuses any host other than `rest.datafeeds.rolling-insights.com` over `https://` (so the token can never be sent elsewhere), reads the token from `RSC_TOKEN` and sends it URL-encoded (never interpolated into a URL string), prints a redacted request line to stderr, and classifies the outcome. The runner has no endpoint knowledge of its own; build the URL from the spec.

```bash
# Default: the body goes to ./df-out/<path-slug>-<timestamp>.json and stdout gets one summary line
./scripts/df.sh 'https://rest.datafeeds.rolling-insights.com/api/v1/schedule/2026-04-10/NBA'
# http=200 class=ok bytes=<n> content_type=application/json file=./df-out/schedule-2026-04-10-NBA-<timestamp>.json json=object{1} keys=data data=NBA:array[<n>]

# A bare path is prefixed with the base URL
./scripts/df.sh '/team-stats/2025/SOCCER?league=EPL'

# Small payload: print the body inline instead of writing a file
./scripts/df.sh --stdout 'https://rest.datafeeds.rolling-insights.com/api/v1/live/2026-04-10/NBA'

# Choose the output file
./scripts/df.sh --out nba-schedule.json '/schedule/2026-04-10/NBA'

# Print the redacted request line without a token or a request
./scripts/df.sh --dry-run '/play-by-play/MLB?game_id=20260515-9-8'

# Full usage and the exit-code table
./scripts/df.sh --help
```

The summary line reports the HTTP code, the outcome class, the byte count, the content type, the file written, the top-level keys, and the shape under `data` (key names and container sizes only, never values). Exit codes distinguish each outcome: `0` valid JSON, `2` usage error or refused URL, `3` missing token, `4` network failure, `5` timeout, `6` HTTP 304, `7` HTTP error (4xx/5xx or an unfollowed redirect), `8` non-JSON body, `9` malformed JSON.

Never put `RSC_token=` in the URL: the runner refuses it. For live polling, send no-cache headers and a timestamp cache buster; the runner does this automatically.

`scripts/route.jq` resolves one route of the spec with jq 1.6 or later and nothing else:

```bash
jq -f scripts/route.jq --arg path '/live/{date}/NBA' /tmp/spec.json
```

It prints one object with the route's `path`, `summary`, `description`, `parameters`, and `response` (the 200 JSON schema with every `$ref` expanded). An unknown path exits 1 and names the closest spec paths.

## Reference guide

- [`references/mcp.md`](references/mcp.md): the MCP server: setup pointer, tools, limits, error texts
- [`references/api.md`](references/api.md): the REST API: authentication, the runner, the spec commands, troubleshooting
- [`references/data-model.md`](references/data-model.md): identifiers, joins, dates, seasons, and the empty-slate behaviour, verified live

## License

This repository is licensed under the MIT License.

The MIT License applies only to the software, code, examples, and documentation contained in this repository. It does not grant any rights to Rolling Insights' proprietary data feeds, APIs, databases, services, trademarks, credentials, RSC_tokens, or other commercial offerings.

Access to DataFeeds by Rolling Insights requires a valid RSC_token and is governed by Rolling Insights' applicable terms of service, subscription terms, and data licensing agreements. A 30-day free trial is available at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register).
