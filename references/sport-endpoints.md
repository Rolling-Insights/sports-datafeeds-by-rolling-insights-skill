# Sports DataFeeds by Rolling Insights — Endpoint Matrix

Use this file to answer “does this sport support X?” before calling an endpoint. Classifications are from live REST checks, not documentation exports. Every cell is one of: live-verified supported, live-verified unsupported, entitlement-blocked, or untested.

## Base patterns

Add `?RSC_token=...` to every request. Optional filters are appended as query parameters.

- `schedule`: `GET /api/v1/schedule/{date}/{SPORT}`
- `schedule-week`: `GET /api/v1/schedule-week/{date}/{SPORT}`
- `schedule-season`: `GET /api/v1/schedule-season/{season_or_year}/{SPORT}`
- `live`: `GET /api/v1/live/{date}/{SPORT}`
- `play-by-play`: `GET /api/v1/play-by-play/{SPORT}?game_id=...`
- `field`: `GET /api/v1/field/{SPORT}?game_id=...`
- `events`: `GET /api/v1/events/{date}/{SPORT}` where documented
- `team-info`: `GET /api/v1/team-info/{SPORT}`
- `team-stats`: `GET /api/v1/team-stats/{season_or_year}/{SPORT}`; some vendor examples also show `GET /api/v1/team-stats/{SPORT}` for current season
- `player-info`: `GET /api/v1/player-info/{SPORT}`
- `player-stats`: `GET /api/v1/player-stats/{season_or_year}/{SPORT}`; some vendor examples also show `GET /api/v1/player-stats/{SPORT}` for current season
- `injuries`: `GET /api/v1/injuries/{SPORT}`
- `depth-charts`: `GET /api/v1/depth-charts/{SPORT}`

For season-stat endpoints, use the year the season started unless the vendor doc for that sport says otherwise.

## Quick resource availability

Legend: ✅ live-verified supported, — live-verified unsupported or no data. Season-less `/player-stats/{SPORT}` and `/team-stats/{SPORT}` notes are in each sport section.

| Sport code | Player info | Player season stats | Team info | Team season stats | Player injuries | Depth charts |
| --- | --- | --- | --- | --- | --- | --- |
| `MLB` | ✅ `/player-info/MLB` | ✅ `/player-stats/{season}/MLB` | ✅ `/team-info/MLB` | ✅ `/team-stats/{season}/MLB` | ✅ `/injuries/MLB` | ✅ `/depth-charts/MLB` |
| `NFL` | ✅ `/player-info/NFL` | ✅ `/player-stats/{season}/NFL` | ✅ `/team-info/NFL` | ✅ `/team-stats/{season}/NFL` | ✅ `/injuries/NFL` | ✅ `/depth-charts/NFL` |
| `NBA` | ✅ `/player-info/NBA` | ✅ `/player-stats/{season}/NBA` | ✅ `/team-info/NBA` | ✅ `/team-stats/{season}/NBA` | ✅ `/injuries/NBA` | ✅ `/depth-charts/NBA` |
| `NHL` | ✅ `/player-info/NHL` | ✅ `/player-stats/{season}/NHL` | ✅ `/team-info/NHL` | ✅ `/team-stats/{season}/NHL` | ✅ `/injuries/NHL` | ✅ `/depth-charts/NHL` |
| `NCAABB` | ✅ `/player-info/NCAABB` | ✅ `/player-stats/{season}/NCAABB` | ✅ `/team-info/NCAABB` | ✅ `/team-stats/{season}/NCAABB` | ✅ `/injuries/NCAABB` | ✅ `/depth-charts/NCAABB` |
| `NCAAFB` | ✅ `/player-info/NCAAFB` | ✅ `/player-stats/{season}/NCAAFB` | ✅ `/team-info/NCAAFB` | ✅ `/team-stats/{season}/NCAAFB` | ✅ `/injuries/NCAAFB` | — |
| `SOCCER` + `league` | ✅ `/player-info/SOCCER?league=EPL\|LALIGA\|SERIEA` | ✅ `/player-stats/{season}/SOCCER?league=...` | ✅ `/team-info/SOCCER?league=...` | ✅ `/team-stats/{season}/SOCCER?league=...` | ✅ `/injuries/SOCCER?league=...` | ✅ `/depth-charts/SOCCER?league=...` |
| `DARTS` | ✅ `/player-info/DARTS` | ✅ `/player-stats/{season}/DARTS` | — | — | — | — |
| `PGA` | ✅ `/player-info/PGA` | ✅ `/player-stats/PGA` | — | — | — | — |

## MLB
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries
- depth-charts
- play-by-play

Resource access:
- Player info: `GET /player-info/MLB`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/MLB`; optional `team_id` or `player_id`. Season-less `/player-stats/MLB` is live-verified for current stats.
- Team info: `GET /team-info/MLB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/MLB`; optional `team_id`. Season-less `/team-stats/MLB` is live-verified.
- Player injuries: `GET /injuries/MLB`; optional `team_id`.
- Depth charts: `GET /depth-charts/MLB`; optional `team_id`.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule` and `live` support `game_id`.
- `play-by-play` is documented for MLB and requires `game_id`.
- `schedule-season` and `schedule-week` support `team_id`.

## NFL
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries
- depth-charts
- play-by-play

Resource access:
- Player info: `GET /player-info/NFL`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NFL`; optional `team_id` or `player_id`. Season-less `/player-stats/NFL` returned no data (304); keep the season path.
- Team info: `GET /team-info/NFL`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NFL`; optional `team_id`. Season-less `/team-stats/NFL` is live-verified.
- Player injuries: `GET /injuries/NFL`; optional `team_id`.
- Depth charts: `GET /depth-charts/NFL`; optional `team_id`.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule` and `live` support `game_id`.
- `play-by-play` is documented for NFL and requires `game_id`.
- `schedule-season` and `schedule-week` are documented for broader discovery.
- Fantasy values such as `DK_fantasy_points` can appear in live/player/team stats; they are not separate endpoints.

## NBA
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries
- depth-charts
- play-by-play

Resource access:
- Player info: `GET /player-info/NBA`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NBA`; optional `team_id` or `player_id`. Season-less `/player-stats/NBA` returned no data (304); keep the season path.
- Team info: `GET /team-info/NBA`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NBA`; optional `team_id`. Season-less `/team-stats/NBA` is live-verified.
- Player injuries: `GET /injuries/NBA`; optional `team_id`.
- Depth charts: `GET /depth-charts/NBA`; optional `team_id`.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule`, `live`, and `play-by-play` support `game_id`.
- `play-by-play` is documented for NBA and follows the same request format as MLB/NFL.

## NHL
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries
- depth-charts

Resource access:
- Player info: `GET /player-info/NHL`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NHL`; optional `team_id` or `player_id`. Season-less `/player-stats/NHL` is live-verified for current stats.
- Team info: `GET /team-info/NHL`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NHL`; optional `team_id`. Season-less `/team-stats/NHL` is live-verified.
- Player injuries: `GET /injuries/NHL`; optional `team_id`.
- Depth charts: `GET /depth-charts/NHL`; optional `team_id`.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule` and `live` support `game_id`.

## NCAABB
Use `NCAABB` in API paths. Normalize user-facing variants like “NCAA BB” or `NCAA_BB` to `NCAABB` before calling REST.

Live-verified endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries
- depth-charts

Resource access:
- Player info: `GET /player-info/NCAABB`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NCAABB`; optional `team_id` or `player_id`. Season-less `/player-stats/NCAABB` is live-verified.
- Team info: `GET /team-info/NCAABB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NCAABB`; optional `team_id`. Season-less `/team-stats/NCAABB` is live-verified.
- Player injuries: `GET /injuries/NCAABB`; optional `team_id`. The endpoint returns 200; injury arrays may be null or empty.
- Depth charts: `GET /depth-charts/NCAABB`; optional `team_id`. Club-keyed position groups (`PG`/`SG`/`SF`/`PF`/`C`).

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule` and `live` support `game_id`.
- Play-by-play, `field`, and `events` are live-verified unsupported for NCAABB.

## NCAAFB
Use `NCAAFB` in API paths. Normalize user-facing variants like “NCAA FB” or `NCAA_FB` to `NCAAFB` before calling REST.

Live-verified endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats
- injuries

Resource access:
- Player info: `GET /player-info/NCAAFB`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NCAAFB`; optional `team_id` or `player_id`. Season-less `/player-stats/NCAAFB` is live-verified.
- Team info: `GET /team-info/NCAAFB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NCAAFB`; optional `team_id`. Season-less `/team-stats/NCAAFB` is live-verified.
- Player injuries: `GET /injuries/NCAAFB`; optional `team_id`. The endpoint returns 200; injury arrays may be null or empty.
- Depth charts: live-verified unsupported (`404` on `/depth-charts/NCAAFB`).

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, and `injuries` support `team_id`.
- `schedule` and `live` support `game_id`.
- Do not call NCAAFB depth-charts, play-by-play, `field`, or `events`.

## DARTS
Live-verified endpoints:
- schedule
- schedule-week
- schedule-season
- events
- live
- player-info
- player-stats

Resource access:
- Events: `GET /events/{date}/DARTS`; optional `event_id`. DARTS is the only sport with a live-verified `events` feed.
- Player info: `GET /player-info/DARTS`; optional `player_id`.
- Player season stats: `GET /player-stats/{season}/DARTS`; optional `player_id`. Season-less `/player-stats/DARTS` is live-verified for current stats.
- Team info: live-verified unsupported (no data).
- Team season stats: live-verified unsupported (`404`).
- Player injuries: live-verified unsupported (no data).
- Depth charts: live-verified unsupported (no data).

Notes:
- Darts has no team resources.
- Use `player-info` for player identity/rank/profile details.
- Use `player-stats` for season performance and scoreboard-derived stats; stats may lag live leg state.
- Play-by-play and `field` are live-verified unsupported.

## PGA
Live-verified endpoints:
- schedule
- schedule-week
- schedule-season
- live
- field
- player-info
- player-stats

Resource access:
- Player info: `GET /player-info/PGA`.
- Player season stats: `GET /player-stats/PGA` is the default current-season form and is live-verified. `/player-stats/{season}/PGA` is also live-verified.
- Team info: live-verified unsupported (no data).
- Team season stats: live-verified unsupported (no data).
- Player injuries: live-verified unsupported (no data).
- Depth charts: live-verified unsupported (no data).

Notes:
- `field` is core PGA functionality: `GET /field/PGA?game_id=YYYY_N`. PGA is the only sport with a live-verified `field` feed.
- Use `field` for tournament roster, tee times, and player IDs.
- `schedule`, `schedule-week`, and `schedule-season` support tournament/game lookup variants.
- Play-by-play and `events` are live-verified unsupported.
- `odds` was mentioned in one doc fragment but is treated as a typo / stray mention and is excluded.

## Soccer / SOCCER
Use `SOCCER` in the path and `league=EPL|LALIGA|SERIEA` in the query string. `league` is required on soccer endpoints; omitting it returns `404` “URL structure error”. An unrecognized league (for example `WORLDCUP`) returns `304` rather than a validation error.

Live-verified endpoints:
- team-info
- schedule / daily schedule
- schedule-week / weekly schedule
- schedule-season
- live
- player-info
- player-stats
- team-stats
- injuries
- depth-charts

Resource access:
- Player info: `GET /player-info/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id` or `player_id`.
- Player season stats: `GET /player-stats/{season}/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id` or `player_id`. Season-less `/player-stats/SOCCER?league=...` is live-verified. Stats nest under `regular_season` (goals, assists, saves, cards — no `points` field).
- Team info: `GET /team-info/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`, optional `relegated=TRUE|FALSE`.
- Team season stats: `GET /team-stats/{season}/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`. Season-less `/team-stats/SOCCER?league=...` is live-verified. Responses are keyed by league (`data.EPL`, `data.LALIGA`, `data.SERIEA`). Recorded stats nest under `regular_season` (`wins`, `draws`, `losses`, `games_played`, `goals_scored`); there is no `points` field — compute `wins * 3 + draws` when a table is requested. Some clubs can appear with null `regular_season` (for example relegated sides).
- Player injuries: `GET /injuries/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`.
- Depth charts: `GET /depth-charts/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`. Club-keyed groups: `Forward`, `Midfielder`, `Defender`, `Goalkeeper`.

Notes:
- Soccer leagues are selected via the `league` query parameter, not the path.
- Use `SOCCER` as the sport code; do not create separate sport-path assumptions for EPL/LALIGA/SerieA.
- Play-by-play is live-verified unsupported (`500` “Invalid or unsupported sport”). `events` and `field` are live-verified unsupported.

## Odds, predictions, and fantasy notes
- No verified REST `odds` or `predictions` endpoint is exposed by this skill.
- If asked for odds/predictions, do not fabricate a product; explain the gap and offer supported schedule/live/stat data.
- Fantasy values are fields inside some football payloads, not a separate endpoint in this skill.
