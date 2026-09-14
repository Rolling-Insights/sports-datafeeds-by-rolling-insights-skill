# End-to-End Examples

Each example shows a realistic user prompt, the request sequence the agent should run, an abridged response, and the answer to return. Token is shown as `$RSC` and elided from URLs; in practice it is set via `RSC_TOKEN`.

All `live` URLs include `&_={ms_timestamp}` and the headers `Cache-Control: no-cache, no-store` and `Pragma: no-cache`. Omitted below for brevity; the bundled scripts add them automatically.

---

## Example 1 — "Who won the Lakers game tonight?" (NBA, live → score)

**Resolve date** to today's local date, e.g. `2026-05-16`.

**Step 1 — find the game.**
```
GET /schedule/2026-05-16/NBA?RSC_token=$RSC
```
Abridged response:
```json
{
  "data": {
    "NBA": [
      {
        "game_ID": "20260516-14-13",
        "home_team": "Los Angeles Lakers",
        "away_team": "Denver Nuggets",
        "event_date": "2026-05-16T22:30:00-04:00",
        "status": "Scheduled"
      }
    ]
  }
}
```
Match the Lakers row → keep `game_ID = 20260516-14-13`.

**Step 2 — live score.**
```
GET /live/2026-05-16/NBA?RSC_token=$RSC&game_id=20260516-14-13
```
Abridged response:
```json
{
  "data": {
    "NBA": [{
      "game_ID": "20260516-14-13",
      "status": "Final",
      "full_box": {
        "home_team": { "name": "Los Angeles Lakers", "score": 112 },
        "away_team": { "name": "Denver Nuggets", "score": 108 }
      }
    }]
  }
}
```

**Step 3 — answer.**
> Lakers 112, Nuggets 108 (Final).

If `status` is still `Scheduled` or `In Progress`, lead with that state instead of "Final" and report the current score.

---

## Example 2 — "Give me a turning-point recap of last night's Yankees game." (MLB, schedule → play-by-play)

**Step 1 — find the game** (yesterday's date, e.g. `2026-05-15`):
```
GET /schedule/2026-05-15/MLB?RSC_token=$RSC
```
Find the row where `home_team` or `away_team` matches "Yankees" → keep `game_ID` (e.g. `20260515-9-8`).

**Step 2 — play-by-play.**
```
GET /play-by-play/MLB?RSC_token=$RSC&game_id=20260515-9-8
```
Abridged response:
```json
{
  "data": {
    "MLB": [{
      "game_ID": "20260515-9-8",
      "innings": [
        {
          "inning": 7, "half": "top",
          "events": [
            { "seq": 41, "type": "HR", "batter": "Aaron Judge",
              "description": "Aaron Judge homers (12) on a fly ball.",
              "score_home": 3, "score_away": 5,
              "leverage_index": 2.4 }
          ]
        }
      ]
    }]
  }
}
```

**Step 3 — pick the turning point.** Choose the event with the highest available leverage signal (`leverage_index` or, lacking that, the largest swing in `score_home`/`score_away`). Cite the field used.

**Step 4 — answer.**
> Turning point: top of the 7th, Aaron Judge's two-run homer flipped the score from 3-3 to 5-3 (leverage_index 2.4). The Yankees held on 5-3.

---

## Example 3 — "Who's in the field at this week's PGA event and when do they tee off?" (PGA, field)

**Step 1 — find the active tournament.** If the user gives no tournament hint:
```
GET /schedule/2026-05-16/PGA?RSC_token=$RSC
```
Read `data.PGA[0].tournament_ID` or `game_ID` (PGA uses `YYYY_N` form, e.g. `2026_19`).

**Step 2 — field + tee times.**
```
GET /field/PGA?RSC_token=$RSC&game_id=2026_19
```
Abridged response:
```json
{
  "data": {
    "PGA": [{
      "tournament_ID": "2026_19",
      "field": [
        { "player_ID": 1234, "first_name": "Scottie", "last_name": "Scheffler",
          "tee_time": "2026-05-16T08:42:00-04:00", "starting_hole": 1 },
        { "player_ID": 1287, "first_name": "Rory", "last_name": "McIlroy",
          "tee_time": "2026-05-16T13:18:00-04:00", "starting_hole": 10 }
      ]
    }]
  }
}
```

**Step 3 — answer.**
> Two of the headliners: Scottie Scheffler tees off 8:42 AM ET from hole 1; Rory McIlroy 1:18 PM ET from hole 10. Field of N players total.

Preserve `player_ID` if you'll later call `/player-stats/PGA` or `/player-info/PGA`.

---

## Example 4 — "What's the EPL table look like this season?" (Soccer, standings from team-stats)

There is no standings endpoint. Build the table from `team-stats` for `SOCCER` with a documented `league` (`EPL`, `LALIGA`, or `SERIEA`). The shapes and numbers below were captured from live `team-stats` responses on 2026-09-14 (EPL, LALIGA, and SERIEA; seasons 2024, 2025, and the in-progress 2026); the rows shown are from the 2025 EPL response. Step-by-step workflow: `references/workflows.md` §8.

**Step 1 — pull season team stats.** Use the year the season started; for the 2025-2026 EPL season pass `2025`:
```
GET /team-stats/2025/SOCCER?RSC_token=$RSC&league=EPL
```
Abridged response — three representative rows; other counting stats (`corners`, `saves`, `shots_*`, `fouls_*`, `free_kicks_*`, cards, penalties) elided:
```json
{
  "data": {
    "EPL": [
      { "team_id": 1, "team": "Arsenal",
        "regular_season": { "games_played": 38, "wins": 26, "draws": 7, "losses": 5,
                            "goals_scored": 71, "goals_conceded": 27, "goals_conceeded": 0, "clean_sheets": 19 } },
      { "team_id": 5, "team": "Cardiff City", "regular_season": null },
      { "team_id": 8, "team": "Everton",
        "regular_season": { "games_played": 36, "wins": 13, "draws": 9, "losses": 14,
                            "goals_scored": 45, "goals_conceded": 45, "ties": 0, "clean_sheets": 11 } }
    ]
  }
}
```

What the response actually looks like:
- Keyed by the league (`data.EPL`), not `data.SOCCER`. Each row is `{ team_id, team, regular_season }`; no `postseason` key was observed on soccer team-stats.
- The array lists more clubs than the league holds (30 rows for the 20-club EPL). Clubs outside the top flight that season come back with `regular_season: null`. In every capture the populated rows numbered exactly 20, matching league size; the null set changes from season to season.
- There is no `points` field and no goal-difference field. Compute `points = wins * 3 + draws` and `goal_difference = goals_scored - goals_conceded`.
- Coverage is not guaranteed complete even for a finished season: in the 2025 EPL response six clubs showed 36 or 37 of 38 matches. `wins + draws + losses` equalled `games_played` on every row, so `games_played` is the number of matches recorded, not the schedule length.
- Goals against: read `goals_conceded`. A misspelled `goals_conceeded` key also appears. In the 2024 season it was the only goals-against key and held the real value; in 2025 it sat beside `goals_conceded` on most rows with a small number that does not match goals against. Fall back to `goals_conceeded` only when `goals_conceded` is absent; never add the two.
- Stray keys happen (Everton carries `ties: 0` above). Map only the fields you need.

**Step 2 — build the table, null-safe.**
```python
LEAGUE = "EPL"
rows = payload.get("data", {}).get(LEAGUE, [])
table, no_stats = [], []
for row in rows:
    rs = row.get("regular_season")
    if not rs:                              # null → not in this season's table; no arithmetic
        no_stats.append(row.get("team"))
        continue
    n = lambda key: rs.get(key) or 0        # missing/null counter → 0
    w, d, l = n("wins"), n("draws"), n("losses")
    gf = n("goals_scored")
    ga = rs.get("goals_conceded")
    if ga is None:                          # older seasons expose only the misspelled key
        ga = n("goals_conceeded")
    table.append({"team": row["team"], "team_id": row["team_id"],
                  "played": rs.get("games_played") or (w + d + l),
                  "w": w, "d": d, "l": l, "gf": gf, "ga": ga,
                  "gd": gf - ga, "points": w * 3 + d})
table.sort(key=lambda t: (-t["points"], -t["gd"], -t["gf"]))
max_played = max((t["played"] for t in table), default=0)   # empty table → 0, no ValueError
short = [(t["team"], t["played"]) for t in table if t["played"] < max_played]
```

Sort order is points, then goal difference, then goals scored — the first three Premier League tiebreakers. La Liga and Serie A rank level clubs on head-to-head results first, which `team-stats` cannot supply, so present level clubs in those leagues as level.

**Step 3 — answer, and say what the numbers are.**

> EPL 2025-26, computed from DataFeeds `team-stats` (`regular_season`); points = wins × 3 + draws:
> 1. Arsenal — 85 pts (38 played, 26-7-5, GD +44)
> 2. Manchester City — 78 pts (38, 23-9-6, +42)
> 3. Manchester United — 71 pts (38, 20-11-7, +20)
> …
> 7. Brighton & Hove Albion — 53 pts (38, 14-11-13, +7); 8. Brentford — 53 (38, +6); 9. Sunderland — 53 (37, −6)
>
> Coverage: 20 clubs have recorded stats. 14 show all 38 matches; Everton (36), Fulham, Newcastle, Tottenham, Leeds, and Sunderland (37 each) are short, so their points may still rise. Ten further clubs in the response have no 2025 stats and are omitted. This is derived from the API's counting stats, not an official table.

Always include the coverage line when any club's `games_played` is below the maximum, when clubs were omitted for null stats, or when the season is in progress (early-season 2026 rows ranged from 1 to 5 matches per club). If every populated club shows the same `games_played`, say that instead.

**Other leagues, same shape.** The 2025 LALIGA response had 26 rows, 6 null, and three clubs at 37 of 38 (Barcelona, Atlético Madrid, Elche). The 2025 SERIEA response had 24 rows, 4 null, and ten clubs below 38, with AS Roma (37 played) and AC Milan (38) level on 70 points — exactly the case the coverage line exists for.

Soccer `player-stats`, `injuries`, and `depth-charts` are live-verified when `league=EPL|LALIGA|SERIEA` is set. Player stats also nest under `regular_season`.

---

## Example 5 — "Build me a Python client that pulls today's NBA scores every minute." (developer use case)

Hand the developer this skeleton — it mirrors the bundled bash scripts but in Python, and demonstrates the cache-busting + 304 handling contract.

```python
import os, time, requests

BASE = "https://rest.datafeeds.rolling-insights.com/api/v1"
TOKEN = os.environ["RSC_TOKEN"]

def live_nba(date: str) -> dict:
    url = f"{BASE}/live/{date}/NBA"
    params = {"RSC_token": TOKEN, "_": int(time.time() * 1000)}
    headers = {
        "Accept": "application/json",
        "Cache-Control": "no-cache, no-store",
        "Pragma": "no-cache",
    }
    r = requests.get(url, params=params, headers=headers, timeout=10)
    if r.status_code == 304:
        # treat as transient cache problem; caller should retry with a new buster
        raise RuntimeError("304 Not Modified — retry with fresh cache-buster")
    r.raise_for_status()
    return r.json()

if __name__ == "__main__":
    today = time.strftime("%Y-%m-%d")
    while True:
        try:
            payload = live_nba(today)
            for game in payload.get("data", {}).get("NBA", []):
                box = game.get("full_box", {})
                home = box.get("home_team", {})
                away = box.get("away_team", {})
                print(f"{away.get('name')} {away.get('score')} @ "
                      f"{home.get('name')} {home.get('score')} "
                      f"[{game.get('status')}]")
        except Exception as e:
            print(f"err: {e}")
        time.sleep(60)
```

Key contract points the developer must keep:
- Token in env var, never in source.
- New `_=` buster on every request.
- `304` is a retry signal, not success.
- Parse `data.NBA[].full_box.{home_team,away_team}.score` defensively — fields may be missing pregame.

---

## Common across all examples

- Always inspect `data` first, then the sport-keyed array (`data.NBA`, `data.MLB`, `data.PGA`, etc.). Soccer is keyed by `league` (`data.EPL`, `data.LALIGA`, `data.SERIEA`).
- If a response is empty for a known-active sport, treat it as a 304-class staleness issue first and retry once with a fresh buster before reporting "no data".
- Cite the field name(s) you used when surfacing facts to the user — it makes the answer auditable and makes wrong fields easy to spot.
