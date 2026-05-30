# DataFeeds by Rolling Insights: AI Skill for Sports Data

Connect AI agents and developer tools to live scores, player stats, schedules, injuries, play-by-play, and more across 9 sports leagues.

This repository contains the skill instructions, REST API reference material, and helper scripts for integrating DataFeeds by Rolling Insights into AI agents, custom GPTs, and developer tools like Cursor and Codex. It is designed to help agents authenticate, discover game IDs, fetch live or historical sports data, and parse sport-specific payloads consistently and safely.

A fully functional 30-day free trial is available at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register). No credit card required.

## What you can build

- **Fantasy sports agents** that pull injury reports, compare player stats, and surface DraftKings fantasy points across NFL, NBA, and MLB
- **Live scoreboard bots** that post real-time scores, box scores, and quarter-by-quarter updates to Discord, Slack, or a web app
- **AI recap generators** that use play-by-play and stat data to produce game summaries and player performance breakdowns
- **Sports LLM pipelines** that feed historical game and player data to custom models for projection, prediction, and DFS optimization

## Supported sports

The bundled references cover these API sport codes:

- `NHL`
- `NBA`
- `NFL`
- `MLB`
- `NCAABB`
- `NCAAFB`
- `SOCCER` with `league=EPL`, `league=LALIGA`, or `league=SERIEA`
- `DARTS`
- `PGA`

Payload shapes and endpoint availability vary by sport. Check [`references/sport-endpoints.md`](references/sport-endpoints.md) before using player info, team info, season stats, injuries, or depth charts.

## Quick start

### 1. Get a free trial token

Register at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register) for a 30-day fully functional API key. Standard pricing starts at $100/month after the trial. If you are building a sports-tech startup or MVP, [Breakaway Accelerator](https://rolling-insights.com/breakaway-accelerator/) offers discounted access starting at $50/month.

### 2. Set your token

```bash
export RSC_TOKEN='your-token'
```

Never hardcode real tokens in scripts, examples, prompts, or committed files.

### 3. Make your first request

```bash
# Get today's NBA schedule
./scripts/df-schedule.sh 2026-05-20 NBA

# Pull live scores and box data for the same date
./scripts/df-live.sh 2026-05-20 NBA
```

The scripts read your token from `RSC_TOKEN`, print a redacted URL to stderr, and emit raw JSON to stdout. See [`references/examples.md`](references/examples.md) for end-to-end walkthroughs including NBA scores, MLB recaps, PGA field data, Euro Soccer tables, and a Python client example.

## What is included

- `SKILL.md` — Skill instructions for using DataFeeds safely and consistently inside AI agents and developer tools
- `references/` — REST API notes, authentication guidance, endpoint matrices, sport-specific payload shapes, workflows, examples, and troubleshooting
- `scripts/` — Shell helpers for deterministic requests to common REST endpoints

## Authentication

DataFeeds REST requests require a query-string token named `RSC_token`.

Set the token in the supported environment variable:

```bash
export RSC_TOKEN='your-token'
```

You can also override the REST base URL when needed:

```bash
export ROLLING_INSIGHTS_BASE_URL='https://rest.datafeeds.rolling-insights.com/api/v1'
```

Never hardcode real tokens in scripts, examples, prompts, or committed files.

### Security note

`RSC_token` travels in the URL query string, so it can easily leak through logs, browser history, proxies, referrer headers, screenshots, and copy/paste. Treat it as a long-lived secret:

- **HTTPS only.** Always call `https://rest.datafeeds.rolling-insights.com/api/v1`; never downgrade to `http://`.
- **Keep `RSC_TOKEN` in env vars or a secret store.** Do not commit it, paste it into prompts, or write it into chat transcripts.
- **Do not share raw request URLs.** Avoid pasting full `RSC_token=...` URLs into chats, tickets, logs, screenshots, or browser history. The bundled scripts redact the token from their stderr URL echo.
- **Rotate on suspected exposure.** If the token may have appeared in any of the channels above, rotate it via the API Locker before continuing.

See [`references/auth.md`](references/auth.md) for the full credential-handling guidance.

## Common REST patterns

```text
GET /schedule/{date}/{SPORT}
GET /live/{date}/{SPORT}
GET /play-by-play/{SPORT}?game_id=...
GET /field/{SPORT}?game_id=YYYY_N
GET /team-info/{SPORT}
GET /team-stats/{season_or_year}/{SPORT}
GET /player-info/{SPORT}
GET /player-stats/{season_or_year}/{SPORT}
GET /injuries/{SPORT}
GET /depth-charts/{SPORT}
GET /schedule-season/{date_or_year}/{SPORT}
GET /schedule-week/{date}/{SPORT}
```

Use REST first for schedules, live feeds, play-by-play, fields, team and player reference data, and season or week discovery.

## Helper scripts

The scripts read the token from `RSC_TOKEN`, print a redacted URL to stderr, and emit raw JSON to stdout.

```bash
# Schedule
./scripts/df-schedule.sh 2026-04-10 NBA

# Live feed
./scripts/df-live.sh 2026-04-10 NBA

# Generic endpoint helper
./scripts/df-rest.sh live 2026-04-10 NBA

# Play-by-play
./scripts/df-play-by-play.sh MLB 20260515-9-8

# PGA field
./scripts/df-field.sh PGA 2026_19
```

For live polling, send no-cache headers and a timestamp cache buster. The bundled scripts do this automatically.

## Reference guide

- [`references/overview.md`](references/overview.md) — Product and endpoint overview
- [`references/auth.md`](references/auth.md) — Token handling and credential guidance
- [`references/rest-api-reference.md`](references/rest-api-reference.md) — Endpoint details and request examples
- [`references/sport-endpoints.md`](references/sport-endpoints.md) — Per-sport endpoint availability matrix
- [`references/sport-shapes.md`](references/sport-shapes.md) — Sport-specific response shape notes
- [`references/workflows.md`](references/workflows.md) — Common request sequences
- [`references/troubleshooting.md`](references/troubleshooting.md) — Common failure modes, sparse data, invalid dates, and cache issues
- [`references/examples.md`](references/examples.md) — End-to-end examples for NBA, MLB, PGA, soccer, and Python client usage

## Typical workflow

1. Call `schedule` for a date and sport.
2. Extract the relevant `game_ID` or `tournament_ID`.
3. Call `live` for current score and state, or `play-by-play` for event-level detail on documented MLB, NBA, and NFL games.
4. Normalize the response according to the sport-specific payload shape in [`references/sport-shapes.md`](references/sport-shapes.md).
5. Treat missing or sparse data as a domain condition, not automatically as an API failure.

## License

This repository is licensed under the MIT License.

The MIT License applies only to the software, code, examples, and documentation contained in this repository. It does not grant any rights to Rolling Insights' proprietary data feeds, APIs, databases, services, trademarks, credentials, RSC_tokens, or other commercial offerings.

Access to DataFeeds by Rolling Insights requires a valid RSC_token and is governed by Rolling Insights' applicable terms of service, subscription terms, and data licensing agreements. A 30-day free trial is available at [accounts.rolling-insights.com/register](https://accounts.rolling-insights.com/register).
