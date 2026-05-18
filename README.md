# DataFeeds Sports API

Sports DataFeeds by Rolling Insights API reference material, agent instructions, and helper scripts for working with the REST API.

This repository is designed to help agents and developers authenticate with an `RSC_token`, discover events and game IDs, fetch live or historical sports data, and parse sport-specific payloads across supported sports.

## What Is Included

- `SKILL.md` - Cursor/Codex skill instructions for using Sports DataFeeds safely and consistently.
- `references/` - REST API notes, authentication guidance, endpoint matrices, sport-specific payload shapes, workflows, examples, and troubleshooting.
- `scripts/` - Shell helpers for deterministic requests to common REST endpoints.

## Supported Sports

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

Payload shapes and endpoint availability vary by sport. Check `references/sport-endpoints.md` before using player info, team info, season stats, injuries, or depth charts.

## Authentication

DataFeeds REST requests require a query-string token named `RSC_token`.

Set the token in one of the supported environment variables:

```bash
export ROLLING_INSIGHTS_TOKEN='your-token'
# or
export RSC_TOKEN='your-token'
```

You can also override the REST base URL when needed:

```bash
export ROLLING_INSIGHTS_BASE_URL='https://rest.datafeeds.rolling-insights.com/api/v1'
```

Never hardcode real tokens in scripts, examples, prompts, or committed files.

## Common REST Patterns

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

Use REST first for schedules, live feeds, play-by-play, fields, team/player reference data, and season/week discovery.

## Helper Scripts

The scripts read tokens from `ROLLING_INSIGHTS_TOKEN` or `RSC_TOKEN`, print a redacted URL to stderr, and emit raw JSON to stdout.

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

## Reference Guide

- `references/overview.md` - Product and endpoint overview.
- `references/auth.md` - Token handling and credential guidance.
- `references/rest-api-reference.md` - Endpoint details and request examples.
- `references/sport-endpoints.md` - Per-sport endpoint availability matrix.
- `references/sport-shapes.md` - Sport-specific response shape notes.
- `references/workflows.md` - Common request sequences.
- `references/troubleshooting.md` - Common failure modes, sparse data, invalid dates, and cache issues.
- `references/examples.md` - End-to-end examples for NBA, MLB, PGA, soccer, and Python client usage.

## Typical Workflow

1. Call `schedule` for a date and sport.
2. Extract the relevant `game_ID` or `tournament_ID`.
3. Call `live` for current score/state or `play-by-play` for documented MLB, NBA, or NFL event detail.
4. Normalize the response according to the sport-specific payload shape.
5. Treat missing or sparse data as a domain condition, not automatically as an API failure.

## License

This repository is licensed under the MIT License.

The MIT License applies only to the software, code, examples, and documentation contained in this repository. It does not grant any rights to Rolling Insights’ proprietary data feeds, APIs, databases, services, trademarks, credentials, RSC_tokens, or other commercial offerings.

Access to DataFeeds by Rolling Insights requires a valid RSC_token and is governed by Rolling Insights’ applicable terms of service, subscription terms, and data licensing agreements. A 30-day free trial is available at https://accounts.rolling-insights.com/register.
