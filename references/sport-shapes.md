# Sport Shapes

## General

- Expect a `data` wrapper.
- Expect per-sport keys such as `NBA`, `DARTS`, `PGA`, `MLB`.
- Do not force a single schema across sports.

## NBA

Common fields in live payloads:
- `game_ID`
- `status`
- `game_status`
- `home_team_name`
- `away_team_name`
- `full_box.home_team.score`
- `full_box.away_team.score`
- `game_time` or `clock`

Use `game_status` as the primary live-state string.

NBA play-by-play is documented separately from live box scores and requires `game_id`; use the same request pattern as MLB/NFL.

## DARTS

Common fields in live payloads:
- `game_ID`
- `status`
- `series_name`
- `players[]`
- `current_box.leg`
- `current_box.throwing`
- `current_box.points_to_checkout`

Use `current_box` for stall detection and live state comparisons.

## PGA

Common fields in schedule/live/field payloads:
- `tournament_ID`
- `event_ID`
- `tournament`
- `date`
- `status`
- `field`
- `tee_times`
- `starting_holes`
- `current`

Useful patterns:
- `game_id` is commonly `YYYY_N`
- `data.PGA[0].field` can contain players keyed by numeric ID
- tee time strings are often RFC-style UTC strings

## MLB

Season schedule payloads can include:
- `game_ID`
- `season_type`
- `season`
- `game_time`
- `home_team`
- `away_team`
- `home_pitcher.player`
- `away_pitcher.player`
- venue and geography fields

Play-by-play payloads are documented separately from live box scores. Use `game_ID` from schedule/live as the `game_id` query parameter.

## NFL

Football live and stat payloads can expose fantasy fields such as `DK_fantasy_points` and `DK_fantasy_points_per_game` in player/team stats. Treat these as optional fields and check for existence before summarizing.

NFL play-by-play is documented separately from live box scores and requires `game_id`.

## Soccer

Soccer payloads are keyed by league (`data.EPL`, `data.LALIGA`, `data.SERIEA`), not `data.SOCCER`.

Team-stats and player-stats nest recorded numbers under `regular_season`.

### team-stats (live-verified 2026-09-14: EPL, LALIGA, SERIEA; seasons 2024, 2025, 2026)

Row shape: `{ team_id, team, regular_season }`. Only `regular_season` was observed; no `postseason` key.

- `regular_season` is `null` for clubs outside that season's top flight. The array lists more clubs than the league holds (EPL 30 rows, LALIGA 26, SERIEA 24, all 20-club leagues); the populated rows numbered exactly 20 in every capture, and the null set changes per season.
- Populated `regular_season` keys observed: `games_played`, `wins`, `draws`, `losses`, `goals_scored`, `goals_conceded`, `clean_sheets`, `saves`, `shots_attempted`, `shots_on_goal`, `corners`, `offsides`, `fouls_committed`, `fouls_drawn`, `free_kicks_won`, `free_kicks_conceded`, `yellow_cards`, `red_cards`, `penalties_scored`, `penalty_attempts`, `penalties_faced`, `penalties_conceded`. Key presence varies by row and season; map only what exists.
- No `points` and no goal-difference field. Compute `wins * 3 + draws` and `goals_scored - goals_conceded`.
- `games_played` is the count of matches recorded, not the schedule length: `wins + draws + losses` matched it on every row, and finished seasons still showed clubs at 36 or 37 of 38. In-progress seasons ranged from 1 to 5 matches per club in the same response.
- Goals against is `goals_conceded`. A misspelled `goals_conceeded` key also exists: on the 2024 season it was the only goals-against key and carried the real value; on 2025 it appeared beside `goals_conceded` on most EPL and LALIGA rows with a small value (0 to 4) that does not match goals against, and not at all on SERIEA or 2026 rows. Read `goals_conceded`, fall back to `goals_conceeded` only when `goals_conceded` is absent, never sum them. Treat the misspelling as an observed quirk, not the contract.
- A stray `ties: 0` key appeared on one club; `draws` is the draws field. Secondary counters (`corners`, `fouls_*`, `free_kicks_*`) were `0` on some early-season rows whose other stats were populated, so a `0` there does not prove the stat was collected.

Standings workflow: `references/workflows.md` §8; worked example: `references/examples.md` Example 4.

Depth charts are club-keyed objects with `Forward`, `Midfielder`, `Defender`, `Goalkeeper`, and `team_id` — not a flat array.

## Parsing rule

Always inspect the first payload item for the sport before writing logic. The safest pattern is:

1. identify the sport key
2. verify whether data is an array
3. inspect the first element
4. map only the fields that exist
