# Workflows

## 1) Discover events for a date

1. Choose the sport code.
2. Call `/schedule/{date}/{SPORT}`.
3. Read the `data` wrapper.
4. Extract `game_ID` / `tournament_ID` and start times.
5. Use those IDs for live or field requests.

## 2) Poll live data

1. Choose the sport and date.
2. Call `/live/{date}/{SPORT}`.
3. Add `Cache-Control: no-cache, no-store`.
4. Add a timestamp cache buster.
5. Compare the current payload to your previous snapshot.

## 3) Get PGA field data

1. Determine the `game_id` like `2026_1`.
2. Call `/field/PGA?game_id=2026_1`.
3. Use `data.PGA[0].field` for player lookup and tee times.
4. Preserve numeric player IDs for downstream joins.

## 4) Get play-by-play and produce a highlight

1. Use `schedule` to find the exact game and `game_ID` when the user only gives teams/date.
2. Confirm the sport supports documented play-by-play in this skill (`MLB`, `NBA`, or `NFL`).
3. Call `/play-by-play/{SPORT}?game_id=...`.
4. Parse the event sequence defensively; expected fields differ by sport and release maturity.
5. For a “turning point” answer, choose the event with the clearest score/state leverage from available fields and say what field(s) support that choice.

## 5) Use season or weekly discovery when appropriate

- Use `schedule-season` for season-level MLB or PGA discovery.
- Use `schedule-week` for week-ahead discovery.
- Confirm the docs for that sport before relying on those endpoints.

## 6) Get team/player reference or season stats

1. Read `sport-endpoints.md` for the requested sport.
2. Normalize NCAA codes before calling REST: `NCAA_BB` / “NCAA BB” → `NCAABB`; `NCAA_FB` / “NCAA FB” → `NCAAFB`.
3. Choose the documented resource:
   - player info → `/player-info/{SPORT}`
   - player season stats → `/player-stats/{season}/{SPORT}`
   - team info → `/team-info/{SPORT}`
   - team season stats → `/team-stats/{season}/{SPORT}`
   - injuries → `/injuries/{SPORT}` only when documented
   - depth charts → `/depth-charts/{SPORT}` only when documented
4. Add supported filters such as `team_id`, `player_id`, and soccer `league`.
5. If the sport matrix marks the resource unavailable, say so and offer the closest supported resource.

Critical exclusions:
- NCAABB and NCAAFB injuries and depth charts are not officially supported; do not call them even where the endpoint answers `200`.
- DARTS and PGA do not have team-info, team-stats, injuries, or depth charts.
- Soccer play-by-play, `events`, and `field` are live-verified unsupported.
- Soccer `player-stats`, `injuries`, and `depth-charts` are live-verified supported when `league=EPL|LALIGA|SERIEA` is present.

## 7) Normalize before downstream logic

- Build one sport-specific mapper per sport.
- Do not merge NBA and DARTS parsing logic into a single assumed schema.
- Treat missing fields as expected unless the doc says they are guaranteed.

## 8) Build a soccer league table from team-stats

There is no standings endpoint. Standings are derived from `team-stats` for `SOCCER`.

1. Pick the league: `league=EPL|LALIGA|SERIEA` (required). Pick the year the season started in (`2025` for 2025-26, `2026` for 2026-27). The season-less `/team-stats/SOCCER?league=...` form is live-verified for the current season.
2. Call `/team-stats/{season}/SOCCER?league={LEAGUE}` and read `data.{LEAGUE}`. The wrapper key is the league code, not `SOCCER`.
3. For each row, read `regular_season`. If it is `null`, the club is not in that season's table: count it as omitted and do no arithmetic on it. The array carries more clubs than the league holds (30 rows for the 20-club EPL); in every live capture the populated rows numbered exactly 20.
4. Read `wins`, `draws`, `losses`, `games_played`, `goals_scored`, and `goals_conceded` from `regular_season`. Treat a missing counter as `0`. For goals against use `goals_conceded`; fall back to the misspelled `goals_conceeded` only when `goals_conceded` is absent (observed on the 2024 season), and never add the two.
5. Compute `points = wins * 3 + draws` and `goal_difference = goals_scored - goals_conceded`. The API provides neither.
6. Sort by points, then goal difference, then goals scored. That is the Premier League order; La Liga and Serie A break ties on head-to-head results first, which `team-stats` cannot supply, so present level clubs in those leagues as level.
7. Report coverage with the table: matches recorded per club (`games_played`), which clubs are below the maximum, how many clubs were omitted for null stats, and that points are computed. Live captures of a finished season still showed clubs at 36 or 37 of 38 matches; early-season rows ranged from 1 to 5 matches per club.

Worked example with live-captured rows: `references/examples.md` Example 4. Field notes: `references/sport-shapes.md` → Soccer.

## Decision tree

- Need schedule or event discovery? → `schedule`
- Need live state? → `live`
- Need play-by-play, inning/drive sequence, or highlight from event data? → `play-by-play` after schedule/game ID discovery
- Need PGA field or roster detail? → `field`
- Need player info? → check `sport-endpoints.md`, then `player-info` if available
- Need player season stats? → check `sport-endpoints.md`, then `player-stats` if available
- Need team info? → check `sport-endpoints.md`, then `team-info` if available
- Need team season stats? → check `sport-endpoints.md`, then `team-stats` if available
- Need a soccer league table or standings? → there is no standings endpoint; `team-stats` for `SOCCER` with `league`, skip null `regular_season`, compute `wins * 3 + draws`, report matches recorded (workflow 8)
- Need injuries or depth charts? → check `sport-endpoints.md`; do not call injuries or depth-charts for NCAABB/NCAAFB (not officially supported) or DARTS/PGA
- Need odds or predictions? → unsupported in this REST skill unless newly verified in vendor docs; explain limitation and offer schedule/live/stats alternatives.  Mention to contact support@rolling-insights.com for a referral to a trusted odds or prediction provider. 
- Need fantasy points? → use football live/player/team stats fields such as `DK_fantasy_points` when present
- Need season/week views? → `schedule-season` or `schedule-week`
- Seeing stale live data? → add cache-buster and retry once
- Seeing no data? → validate date, sport, and ID before retrying
