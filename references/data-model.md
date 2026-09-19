# Data model: what the spec cannot say

The spec gives every route's parameters and response schema; resolve a route before reading a
field (Rules 3 and 4). This file holds only the facts that live across routes or in the values,
which a schema cannot express. Every item was verified against the live API on 2026-09-19. Data
quality is not covered here: a value that looks wrong is a bug report, not a rule.

## The wrapper

- Every response is `{"data": {"<KEY>": ...}}`. For eight sports the key is the sport code as
  written in the path (`NBA`, `MLB`, `DARTS`, ...). For soccer the key is the **league**, never
  `SOCCER`: `data.EPL`, `data.LALIGA`, `data.SERIEA`, one of them per request, matching the
  `league` parameter.
- Under the key: an array of rows on most routes; a map keyed by team name on depth charts. The
  resolved `response` shows which.

## Game identifiers: `game_ID` across routes

- Schedule rows carry `game_ID` (a string). The same string is the row's `game_ID` on the live
  route for the same date, and the value of the `game_id` query parameter on play-by-play (MLB,
  NBA, NFL) and on the darts and PGA routes that take one. Read it from a schedule; carry it
  verbatim.
- Its form differs by sport and is not a contract: team sports show `YYYYMMDD-<away_team_ID>-<home_team_ID>`
  (`20260917-3-1`: Lions, 3, at Bills, 1); darts shows `YYYYMMDD-<event code>-<player_1_ID>-<player_2_ID>`.
  Never build one; the ids it embeds are on the same row as their own fields.
- PGA has no `game_ID`. Its schedule rows carry `tournament_ID` (a string, `YYYY_N`, `2026_122`)
  and `event_ID` (a number). `tournament_ID` is the value the PGA routes' `game_id` parameter takes,
  including the field route.
- Darts events carry `event_ID` (a string, `20260917WSD`); darts schedule rows carry the same
  `event_ID`, and the `event_id` query parameter on the darts routes takes it.

## Team identifiers and names

- Schedule rows name teams as `home_team` / `away_team` and identify them as `home_team_ID` /
  `away_team_ID` (capital `ID`). Everywhere else the same number is `team_id` (lower case):
  team-info, team-stats, player-info, player-stats, injuries, depth charts, and live
  `full_box.home_team.team_id` / `full_box.away_team.team_id`. Join on the number; the key case
  changes between routes.
- Team names are display strings and vary by route: `team` on info and stats rows,
  `home_team_name` / `away_team_name` on live rows, `abbrv` and `mascot` on team-info and inside
  live `full_box`. Match on ids, not names.
- Verified: MLB team-info `team_id` 28 is the San Diego Padres and 12 the Miami Marlins, the
  `home_team_ID` and `away_team_ID` of schedule row `20260918-12-28`; NFL live `full_box` ids
  1 and 3 match the schedule row `20260917-3-1`; an MLB player-stats row carries `team_id` 26,
  the Pittsburgh Pirates of team-info.

## Player identifiers

- `player_id` is the same number on player-info and player-stats rows, and wherever a schedule
  embeds a player (MLB `home_pitcher.player_id` / `away_pitcher.player_id`, darts `player_1_ID` /
  `player_2_ID`). Verified: MLB pitcher 5787 on the schedule is `player_id` 5787 on player-stats;
  darts `player_id` 1 on player-info is `player_id` 1 on player-stats.
- On live rows, `player_box.home_team` and `player_box.away_team` are maps keyed by the player id
  **as a string** (`"1594": {"player": "Jared Goff", ...}`); the id is the key, not a field.
- On depth charts the map is keyed by team name, then position, then depth order as a string
  (`"1"` is the starter), and the player id is named `id` (`{"id": 425, "player": "Rudy Gobert"}`);
  `team_id` sits beside the positions. Verified on NBA.
- The `player_id` query filter exists only on the darts routes. For every other sport, fetch the
  roster or stats and select the row client-side.

## Dates and times

- The `date` path value is the **league's game day**, not the GMT date of the start time. Evening
  games in the Americas start on the next GMT day and still belong to the day they are played on:
  the NFL game `20260917-3-1` has `game_time` `Fri, 18 Sep 2026 00:15:00 GMT` and is served under
  `/schedule/2026-09-17/NFL` and `/live/2026-09-17/NFL`; `/live/2026-09-18/NFL` answers 304.
  Resolve "today" and "tonight" to the league's local date before building the path.
- `game_time` is an RFC 1123 timestamp in GMT on every schedule and live row checked (MLB, NFL,
  soccer, darts). PGA rows carry `start_time` in the same form beside display strings
  (`date`, `tournament_start`, `tournament_end`).
- Darts event `start_date` / `end_date` are RFC 1123 GMT as well.

## Seasons

- The `season` path parameter is the **year the season started**: `2025` for the 2025-26 NBA,
  NHL and soccer seasons, `2026` for the 2026 MLB season and the 2026-27 NFL season. Some routes
  say so in the parameter description, some do not; the rule holds on all of them.
- The `season` **field** on rows is a display string whose format varies by sport: `"2026"` on
  MLB and darts rows, `"2026-2027"` on NFL and soccer rows. Do not compare it with the path value
  or parse it as a number.
- `season_type` on schedule and live rows is a string such as `Regular Season`.

## Nothing to return

- A date, season or league with no rows answers **HTTP 304 with no body**, not an empty array:
  `/schedule/2026-09-18/NBA` (off-season) and `/live/2026-09-18/NFL` (no game that day) both
  did. Through the runner that is exit 6; through the MCP it is the 304 text. Treat it as "no
  rows for this request" and check the date and season before anything else.

## Status fields

- Live rows carry `game_status`, a free string (`Final`), beside `status`. Use `status` for logic
  and the spec's enum for its value set.
