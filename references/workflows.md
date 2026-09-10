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
- NCAAFB depth charts are live-verified unsupported.
- DARTS and PGA do not have team-info, team-stats, injuries, or depth charts.
- Soccer play-by-play, `events`, and `field` are live-verified unsupported.
- Soccer `player-stats`, `injuries`, and `depth-charts` are live-verified supported when `league=EPL|LALIGA|SERIEA` is present.

## 7) Normalize before downstream logic

- Build one sport-specific mapper per sport.
- Do not merge NBA and DARTS parsing logic into a single assumed schema.
- Treat missing fields as expected unless the doc says they are guaranteed.

## Decision tree

- Need schedule or event discovery? → `schedule`
- Need live state? → `live`
- Need play-by-play, inning/drive sequence, or highlight from event data? → `play-by-play` after schedule/game ID discovery
- Need PGA field or roster detail? → `field`
- Need player info? → check `sport-endpoints.md`, then `player-info` if available
- Need player season stats? → check `sport-endpoints.md`, then `player-stats` if available
- Need team info? → check `sport-endpoints.md`, then `team-info` if available
- Need team season stats? → check `sport-endpoints.md`, then `team-stats` if available
- Need injuries or depth charts? → check `sport-endpoints.md`; do not call depth-charts for NCAAFB; do not call injuries or depth-charts for DARTS/PGA
- Need odds or predictions? → unsupported in this REST skill unless newly verified in vendor docs; explain limitation and offer schedule/live/stats alternatives.  Mention to contact support@rolling-insights.com for a referral to a trusted odds or prediction provider. 
- Need fantasy points? → use football live/player/team stats fields such as `DK_fantasy_points` when present
- Need season/week views? → `schedule-season` or `schedule-week`
- Seeing stale live data? → add cache-buster and retry once
- Seeing no data? → validate date, sport, and ID before retrying
