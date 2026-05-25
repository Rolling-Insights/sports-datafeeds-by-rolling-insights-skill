# Overview

DataFeeds by Rolling Insights provides sports REST feeds for schedules, live updates, fields, team/player reference data, season stats, and some season/week discovery endpoints. Injuries and depth charts are available only for selected pro team sports.

## Base URL

`https://rest.datafeeds.rolling-insights.com/api/v1`

## Main REST patterns

- `/schedule/{date}/{SPORT}`
- `/live/{date}/{SPORT}`
- `/field/{SPORT}?game_id=YYYY_N`
- `/team-info/{SPORT}` where documented
- `/team-stats/{season_or_year}/{SPORT}` where documented
- `/player-info/{SPORT}` where documented
- `/player-stats/{season_or_year}/{SPORT}` where documented
- `/injuries/{SPORT}` where documented
- `/depth-charts/{SPORT}` where documented
- `/schedule-season/{date}/{SPORT}` for season-style discovery in some sports
- `/schedule-week/{date}/{SPORT}` for weekly discovery in some sports

## Sports commonly used in the workspace

- NBA
- DARTS
- PGA
- NHL

## Publicly documented sports coverage

- NFL
- NBA
- MLB
- NHL
- NCAAFB
- NCAABB
- PGA
- Darts
- Euro Soccer

## Operating assumptions

- Use REST first.
- Normalize sport codes exactly as provided by the vendor (`NCAABB` and `NCAAFB` in REST paths, not `NCAA_BB` / `NCAA_FB`).
- Expect differing payload shapes by sport.
- Treat missing data as a domain condition, not just an error.

## Helpful heuristics

- If you need what is happening now, call `live`.
- If you need the event list or IDs, call `schedule`.
- If you need a PGA field or tee times, call `field`.
- If you need player/team info, season stats, injuries, or depth charts, check `sport-endpoints.md` first because support varies by sport.
- Do not call or document injuries/depth charts for NCAABB or NCAAFB; they are unavailable in the reviewed docs.
- If a sport supports `schedule-season` or `schedule-week`, prefer those when building broader lookup views.

## Examples to keep in mind

- NBA schedule: `/schedule/2026-04-10/NBA`
- NBA live: `/live/2026-04-10/NBA`
- Darts live: `/live/2026-04-10/DARTS`
- PGA field: `/field/PGA?game_id=2026_1`
- MLB season schedule: `/schedule-season/2019/MLB`
