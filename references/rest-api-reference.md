# REST API Reference

## Base URL

`https://rest.datafeeds.rolling-insights.com/api/v1`

## Endpoint patterns

### Schedule

```text
GET /schedule/{YYYY-MM-DD}/{SPORT}?RSC_token=...
```

Use for:
- event discovery
- game IDs
- start times
- basic status

Examples:
- `/schedule/2026-04-10/NBA?RSC_token=...`
- `/schedule/2026-04-10/DARTS?RSC_token=...`
- `/schedule/2026-04-10/PGA?RSC_token=...`

### Live

```text
GET /live/{YYYY-MM-DD}/{SPORT}?RSC_token=...&_=TIMESTAMP
```

Use for:
- live scores
- current box state
- play-by-play-ish updates
- round state

Required live-call rules:
- add `Cache-Control: no-cache, no-store`
- add `Pragma: no-cache`
- add a timestamp cache buster like `&_=$(date +%s%3N)`

Examples:
- `/live/2026-04-10/NBA?RSC_token=...&_=1712712345678`
- `/live/2026-04-10/DARTS?RSC_token=...&_=1712712345678`
- `/live/2026-04-10/PGA?RSC_token=...&_=1712712345678`

### Events

```text
GET /events/{YYYY-MM-DD}/{SPORT}?RSC_token=...
```

Use for documented event-series lookup. In the reviewed docs this is documented for DARTS.

Examples:
- `/events/2023-04-06/DARTS?RSC_token=...`
- `/events/2023-04-06/DARTS?RSC_token=...&event_id=202304PL10`

### Play by play

```text
GET /play-by-play/{SPORT}?RSC_token=...&game_id=GAME_ID
```

Use for:
- MLB, NBA, and NFL game event sequences
- inning/period/drive-level recaps where documented
- “turning point” or highlight-style summaries grounded in event data

Rules:
- call `schedule` first if you only have a team/date and need the `game_ID`
- currently treat play-by-play as documented for MLB, NBA, and NFL
- do not substitute `live` if the user specifically asks whether play-by-play exists; explain endpoint support

Examples:
- `/play-by-play/MLB?RSC_token=...&game_id=20250724-9-8`
- `/play-by-play/NBA?RSC_token=...&game_id=20260412-1-2`
- `/play-by-play/NFL?RSC_token=...&game_id=20251009-32-21`

### Field

```text
GET /field/{SPORT}?RSC_token=...&game_id=YYYY_N
```

Use for:
- PGA field lookup
- tee times
- roster discovery
- player IDs for tournament workflows

Example:
- `/field/PGA?RSC_token=...&game_id=2026_1`

### Team/player reference and season-stat endpoints

Check `sport-endpoints.md` before using these endpoints; availability differs by sport.

```text
GET /team-info/{SPORT}?RSC_token=...&team_id=TEAM_ID
GET /team-stats/{season_or_year}/{SPORT}?RSC_token=...&team_id=TEAM_ID
GET /player-info/{SPORT}?RSC_token=...&team_id=TEAM_ID&player_id=PLAYER_ID
GET /player-stats/{season_or_year}/{SPORT}?RSC_token=...&team_id=TEAM_ID&player_id=PLAYER_ID
GET /injuries/{SPORT}?RSC_token=...&team_id=TEAM_ID
GET /depth-charts/{SPORT}?RSC_token=...&team_id=TEAM_ID
```

Use for:
- player identity/profile/roster lookup (`player-info`)
- player season stats (`player-stats`)
- team identity/profile lookup (`team-info`)
- team season stats (`team-stats`)
- player availability where documented (`injuries`)
- lineup/depth order where documented (`depth-charts`)

Rules:
- use the vendor sport code exactly: `NCAABB` and `NCAAFB`, not `NCAA_BB` / `NCAA_FB`, in REST paths
- use the year the season started for `{season_or_year}` unless the sport docs say otherwise
- do not call `injuries` or `depth-charts` for `NCAABB`, `NCAAFB`, `SOCCER`, `DARTS`, or `PGA`; they are not documented in the reviewed REST exports
- soccer requires `league=EPL|LALIGA|SERIEA` on supported soccer endpoints
- DARTS and PGA have player resources but no team resources in the reviewed docs

Examples:
- `/player-info/NBA?RSC_token=...&team_id=1`
- `/player-stats/2023/NBA?RSC_token=...&player_id=3`
- `/team-info/NCAABB?RSC_token=...&team_id=36`
- `/team-stats/2021/NCAAFB?RSC_token=...&team_id=1`
- `/injuries/NFL?RSC_token=...&team_id=1`
- `/depth-charts/MLB?RSC_token=...&team_id=1`
- `/player-info/SOCCER?RSC_token=...&league=EPL&team_id=7`
- `/team-stats/2024/SOCCER?RSC_token=...&league=LALIGA`
- `/player-info/DARTS?RSC_token=...&player_id=1`
- `/player-stats/PGA?RSC_token=...`

### Season and weekly discovery

Some sports expose broader discovery endpoints:

```text
GET /schedule-season/{date_or_year}/{SPORT}?RSC_token=...
GET /schedule-week/{date}/{SPORT}?RSC_token=...
```

Examples documented in the local exports:
- MLB season schedule
- NFL season and weekly schedule
- NHL season and weekly schedule
- DARTS season and weekly schedule
- PGA season schedule
- PGA weekly schedule

## Response wrapper

Most responses are wrapped like:

```json
{
  "data": {
    "NBA": []
  }
}
```

## Status and behavior notes

- `200`: valid JSON response
- `304`: cache/validation behavior; retry with a new cache-buster
- `404`: bad request, wrong path, or unsupported combination
- invalid dates often surface as plain-text errors

## Examples of verified usage

### NBA
- `schedule/2026-04-10/NBA`
- `live/2026-04-10/NBA`
- `team-info/NBA`
- `team-stats/2023/NBA`
- `player-info/NBA`
- `player-stats/2023/NBA`
- `injuries/NBA`
- `depth-charts/NBA`

### Darts
- `schedule-season/2024/DARTS`
- `schedule-week/2024-01-01/DARTS`
- `schedule/2024-01-01/DARTS`
- `events/2023-04-06/DARTS`
- `live/2024-01-01/DARTS`
- `player-info/DARTS`
- `player-stats/DARTS` or `player-stats/{season}/DARTS`

### PGA
- `schedule/2026-04-10/PGA`
- `live/2026-04-10/PGA`
- `field/PGA?game_id=2026_1`
- `player-info/PGA`
- `player-stats/PGA`

### MLB
- `schedule-season/2019/MLB`
- `schedule-season/2019/MLB?team_id=1`
- `team-info/MLB`
- `team-stats/2018/MLB`
- `player-info/MLB`
- `player-stats/2018/MLB`
- `injuries/MLB`
- `depth-charts/MLB`

### College sports
- `team-info/NCAABB`
- `team-stats/2018/NCAABB`
- `player-info/NCAABB`
- `player-stats/2018/NCAABB`
- `team-info/NCAAFB`
- `team-stats/2021/NCAAFB`
- `player-info/NCAAFB`
- `player-stats/2024/NCAAFB`
- NCAABB/NCAAFB injuries and depth charts are unavailable in the reviewed docs.

### Soccer
- `team-info/SOCCER?league=EPL`
- `player-info/SOCCER?league=SERIEA`
- `team-stats/2024/SOCCER?league=LALIGA`
- Soccer player-stats, injuries, and depth charts are unavailable in the reviewed docs.
