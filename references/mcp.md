# The DataFeeds MCP server

A hosted MCP server in front of the same API as the REST surface. The agent's client holds the
token; the agent sees a set of tools and calls them mid-conversation.

## Setup: one pointer

Connection instructions for Claude Code, Cursor and Codex live on the docs site and nowhere else:

```text
https://docs.datafeeds.rolling-insights.com/agent-setup/
```

An agent doing the setup itself reads and runs the agent-addressed version:

```text
https://docs.datafeeds.rolling-insights.com/agent-setup/prompt.md
```

The guide keeps the token out of every config file (a reference to `RSC_TOKEN`, in the syntax each
agent expects), forbids registering the server through a shell command that would expand the
token, and ends with a live data call as the only proof that the setup works. Do not paraphrase it,
copy it, or ask the user for the token to "do it for them".

## Trigger

DataFeeds MCP tools are present in the session. That is the whole test: no hostname assumptions,
no health-check probing, no guessing from the client's name. If the tools are absent, the MCP is
not configured; say so once with the pointer above, and use the REST path if a shell exists.

## The tools

Thirteen tools, one per REST resource. The list in the session is authoritative; this is the same
list for reading without a call.

| Tool | Sports | Arguments |
| --- | --- | --- |
| `get_schedule` | all nine | `sport`, `date`; `league` (soccer); `game_id`, `event_id`, `player_id` (darts / PGA) |
| `get_schedule_week` | all nine | `sport`, `date`; same optional arguments as `get_schedule` |
| `get_schedule_season` | all nine | `sport`, `season`; same optional arguments as `get_schedule` |
| `get_live` | all nine | `sport`, `date`; `league` (soccer); `game_id` (darts / PGA) |
| `get_play_by_play` | mlb, nba, nfl | `sport`, `game_id` (required) |
| `get_player_info` | all nine | `sport`; `league` (soccer); `player_id` (darts) |
| `get_player_stats` | all nine | `sport`, `season` (not for pga); `league` (soccer); `player_id` (darts); `team`, `player_name` (MCP-side filters) |
| `get_team_info` | team sports | `sport`; `league` (soccer) |
| `get_team_stats` | team sports | `sport`, `season`; `league` (soccer); `team` (MCP-side filter) |
| `get_depth_charts` | mlb, nba, ncaabb, nfl, nhl, soccer | `sport`; `league` (soccer) |
| `get_injuries` | mlb, nba, nfl, nhl, soccer | `sport`; `league` (soccer) |
| `get_events` | darts | `sport`, `season`; `event_id` |
| `get_field` | pga | `sport`, `game_id` (required; the tournament id) |

Conventions:

- `sport` is lowercase: `darts`, `mlb`, `nba`, `ncaabb`, `ncaafb`, `nfl`, `nhl`, `pga`, `soccer`.
  Each tool's enum lists the sports it serves.
- `date` is `YYYY-MM-DD`. `season` is a string holding the year the season started (`"2025"` for
  the 2025-26 NBA season).
- `league` is required for soccer and only soccer: `EPL`, `SERIEA`, `LALIGA`.
- `team` and `player_name` on the stats tools are **MCP-side filters**: the server fetches the
  full payload and keeps rows whose team or player name contains the text (case-insensitive).
  They change the row set only, are not sent upstream, and match nothing for darts and PGA players
  (no team). Use them: an unfiltered `get_player_stats` is hundreds of KB.
- `game_id`, `event_id` and `player_id` are passed upstream as the REST query parameters of the
  same name and exist only where the REST route has them (darts, PGA, play-by-play, field).

## Limits: when the MCP cannot do the job

Take the REST path (`references/api.md`) when any of these is the question:

- **HTTP status codes.** The MCP reports a status only inside an error text; a success carries none.
- **A 304 body.** An upstream 304 arrives as a message, never as a body to inspect.
- **The season-less stats form.** `season` is required on the stats tools; the REST routes that
  omit it are not reachable here.
- **A raw upstream error.** Error bodies are redacted and cut to 500 characters.
- **The REST contract.** Tool names, argument names and the MCP's output say nothing about what a
  REST client receives; only the spec and a captured REST response do. Never check a parser
  against MCP output.
- **Large payloads.** A full-league stats or season-schedule payload lands in the agent's context;
  filter, or use the runner, which writes the body to a file.

An observation about today's server, not a contract: an unfiltered success passes the REST body
through unchanged, so a shape read off an unfiltered result matched the REST response of the same
request when this was checked. A server-side sort, limit or summary mode would change that by
design. Parsers are checked only against a REST response captured by the runner (Rule 4).

## Error texts and what to do

A tool result flagged as an error carries one of these texts. `<path>` is the REST path, never the
full URL.

| Text | Meaning | Do |
| --- | --- | --- |
| `DataFeeds returned HTTP 304 with an empty body for <path>.` | Nothing to return for that date, season, league or filter (an off-day, a future date, a season not served, an unrecognised league). It is an answer, not a failure. | Say there is nothing for that request. Check the date is the league's game day and the season is the start year (`references/data-model.md`). If a status code or a retry matters, use the runner (exit 6). |
| `DataFeeds rejected the RSC token (401). Check that the Bearer token sent in the Authorization header is a valid RSC_token.` | The token is wrong, expired, or the client sent the literal `${RSC_TOKEN}` placeholder because the variable was unset when the agent started. | Point to the setup guide (confirm the variable is set in the environment the agent was launched from; restart the agent from that shell). Never ask for the token. Do not retry. |
| `Access denied by DataFeeds (403): <body>` | The token is valid; the plan does not cover that sport or resource. | Say so, offer a sport the plan covers, point to the API Locker for the plan. Do not retry. |
| `Not found (404) for <path>: <body>` | The route or its parameters are wrong (for soccer, a missing `league`). | Check the tool's arguments against its description; on the REST path, Rule 3. |
| `DataFeeds upstream error <status> for <path>: <body>` | Any other upstream status (a 5xx, or a sport the route does not serve). | Report the text as received. To see the full body, use the runner. |
| `DataFeeds request failed (<path>): <message>` | The MCP server could not reach the API (network, timeout). | Retry once; then report it as a network condition, not a token or data problem. |

Seen only while setting up, as JSON-RPC errors from the server itself rather than tool results:
HTTP 401 `Unauthorized: send your DataFeeds RSC token as 'Authorization: Bearer <RSC_token>'` (no
usable header reached the server; the config syntax is wrong for that agent), HTTP 404 (the URL
lacks the `/mcp` path), HTTP 405 (a GET; the server is POST-only). The setup guide covers each.

Every row maps to the same diagnosis as the raw HTTP status in `references/api.md`; the MCP adds no
error of its own beyond the transport ones above.
