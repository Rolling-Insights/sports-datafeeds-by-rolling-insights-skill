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

## Parsing rule

Always inspect the first payload item for the sport before writing logic. The safest pattern is:

1. identify the sport key
2. verify whether data is an array
3. inspect the first element
4. map only the fields that exist
