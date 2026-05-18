# Sports DataFeeds by Rolling Insights — Endpoint Matrix

Use this file to answer “does this sport support X?” before calling an endpoint. The matrix is based on the local Rolling Insights API documentation exports reviewed for MLB, NFL, NBA, NHL, NCAABB, NCAAFB, PGA, DARTS, and Euro Soccer.

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

Legend: ✅ documented, — not documented/unsupported in reviewed REST docs.

| Sport code | Player info | Player season stats | Team info | Team season stats | Player injuries | Depth charts |
| --- | --- | --- | --- | --- | --- | --- |
| `MLB` | ✅ `/player-info/MLB` | ✅ `/player-stats/{season}/MLB` | ✅ `/team-info/MLB` | ✅ `/team-stats/{season}/MLB` | ✅ `/injuries/MLB` | ✅ `/depth-charts/MLB` |
| `NFL` | ✅ `/player-info/NFL` | ✅ `/player-stats/{season}/NFL` | ✅ `/team-info/NFL` | ✅ `/team-stats/{season}/NFL` | ✅ `/injuries/NFL` | ✅ `/depth-charts/NFL` |
| `NBA` | ✅ `/player-info/NBA` | ✅ `/player-stats/{season}/NBA` | ✅ `/team-info/NBA` | ✅ `/team-stats/{season}/NBA` | ✅ `/injuries/NBA` | ✅ `/depth-charts/NBA` |
| `NHL` | ✅ `/player-info/NHL` | ✅ `/player-stats/{season}/NHL` | ✅ `/team-info/NHL` | ✅ `/team-stats/{season}/NHL` | ✅ `/injuries/NHL` | ✅ `/depth-charts/NHL` |
| `NCAABB` | ✅ `/player-info/NCAABB` | ✅ `/player-stats/{season}/NCAABB` | ✅ `/team-info/NCAABB` | ✅ `/team-stats/{season}/NCAABB` | — | — |
| `NCAAFB` | ✅ `/player-info/NCAAFB` | ✅ `/player-stats/{season}/NCAAFB` | ✅ `/team-info/NCAAFB` | ✅ `/team-stats/{season}/NCAAFB` | — | — |
| `SOCCER` + `league` | ✅ `/player-info/SOCCER?league=EPL|LALIGA|SERIEA` | — | ✅ `/team-info/SOCCER?league=...` | ✅ `/team-stats/{season}/SOCCER?league=...` | — | — |
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
- Player season stats: `GET /player-stats/{season}/MLB`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/MLB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/MLB`; optional `team_id`.
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
- Player season stats: `GET /player-stats/{season}/NFL`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/NFL`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NFL`; optional `team_id`.
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
- Player season stats: `GET /player-stats/{season}/NBA`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/NBA`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NBA`; optional `team_id`.
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
- Player season stats: `GET /player-stats/{season}/NHL`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/NHL`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NHL`; optional `team_id`.
- Player injuries: `GET /injuries/NHL`; optional `team_id`.
- Depth charts: `GET /depth-charts/NHL`; optional `team_id`.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, `player-stats`, `injuries`, and `depth-charts` support `team_id`.
- `schedule` and `live` support `game_id`.

## NCAABB
Use `NCAABB` in API paths. Normalize user-facing variants like “NCAA BB” or `NCAA_BB` to `NCAABB` before calling REST.

Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats

Resource access:
- Player info: `GET /player-info/NCAABB`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NCAABB`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/NCAABB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NCAABB`; optional `team_id`.
- Player injuries: unavailable in the reviewed NCAABB REST docs.
- Depth charts: unavailable in the reviewed NCAABB REST docs.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, and `player-stats` support `team_id`.
- `schedule` and `live` support `game_id`.
- Do not document or call NCAABB injuries or depth-charts endpoints.

## NCAAFB
Use `NCAAFB` in API paths. Normalize user-facing variants like “NCAA FB” or `NCAA_FB` to `NCAAFB` before calling REST.

Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- team-info
- team-stats
- player-info
- player-stats

Resource access:
- Player info: `GET /player-info/NCAAFB`; optional `team_id`.
- Player season stats: `GET /player-stats/{season}/NCAAFB`; optional `team_id` or `player_id`.
- Team info: `GET /team-info/NCAAFB`; optional `team_id`.
- Team season stats: `GET /team-stats/{season}/NCAAFB`; optional `team_id`.
- Player injuries: unavailable in the reviewed NCAAFB REST docs.
- Depth charts: unavailable in the reviewed NCAAFB REST docs.

Notes:
- `schedule`, `live`, `team-info`, `team-stats`, `player-info`, and `player-stats` support `team_id`.
- `schedule` and `live` support `game_id`.
- Do not document or call NCAAFB injuries or depth-charts endpoints.

## DARTS
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- events
- live
- player-info
- player-stats

Resource access:
- Events: `GET /events/{date}/DARTS`; optional `event_id`.
- Player info: `GET /player-info/DARTS`; optional `player_id`.
- Player season stats: `GET /player-stats/{season}/DARTS`; optional `player_id`; vendor examples also show `/player-stats/DARTS` for current season.
- Team info: unavailable.
- Team season stats: unavailable.
- Player injuries: unavailable.
- Depth charts: unavailable.

Notes:
- Darts has no team resources in the reviewed REST docs.
- Use `player-info` for player identity/rank/profile details.
- Use `player-stats` for season performance and scoreboard-derived stats; stats may lag live leg state.

## PGA
Documented endpoints:
- schedule
- schedule-week
- schedule-season
- live
- field
- player-info
- player-stats

Resource access:
- Player info: `GET /player-info/PGA`.
- Player season stats: `GET /player-stats/PGA` or documented current-season/year variants where available.
- Team info: unavailable.
- Team season stats: unavailable.
- Player injuries: unavailable.
- Depth charts: unavailable.

Notes:
- `field` is core PGA functionality: `GET /field/PGA?game_id=YYYY_N`.
- Use `field` for tournament roster, tee times, and player IDs.
- `schedule`, `schedule-week`, and `schedule-season` support tournament/game lookup variants.
- `odds` was mentioned in one doc fragment but is treated as a typo / stray mention and is excluded.

## Soccer / SOCCER
Use `SOCCER` in the path and `league=EPL|LALIGA|SERIEA` in the query string.

Documented endpoints:
- team-info
- schedule / daily schedule
- schedule-week / weekly schedule
- schedule-season
- live
- player-info
- team-stats

Resource access:
- Player info: `GET /player-info/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id` or `player_id`.
- Player season stats: unavailable in the reviewed Euro Soccer REST docs.
- Team info: `GET /team-info/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`, optional `relegated=TRUE|FALSE`.
- Team season stats: `GET /team-stats/{season}/SOCCER?league=EPL|LALIGA|SERIEA`; optional `team_id`.
- Player injuries: unavailable in the reviewed Euro Soccer REST docs.
- Depth charts: unavailable in the reviewed Euro Soccer REST docs.

Notes:
- Soccer leagues are selected via the `league` query parameter, not the path.
- Use `SOCCER` as the sport code; do not create separate sport-path assumptions for EPL/LALIGA/SerieA.

## Odds, predictions, and fantasy notes
- No verified REST `odds` or `predictions` endpoint is exposed by this skill.
- If asked for odds/predictions, do not fabricate a product; explain the gap and offer supported schedule/live/stat data.
- Fantasy values are fields inside some football payloads, not a separate endpoint in this skill.
