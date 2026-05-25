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

## Example 4 — "What's the EPL table look like this season?" (Soccer, team-stats with league)

**Step 1 — pull season team stats.** Use the year the season started; for the 2025-2026 EPL season pass `2025`:
```
GET /team-stats/2025/SOCCER?RSC_token=$RSC&league=EPL
```
Abridged response:
```json
{
  "data": {
    "EPL": [
      { "team_ID": 7, "name": "Arsenal", "played": 36, "wins": 25, "draws": 7, "losses": 4, "points": 82 },
      { "team_ID": 11, "name": "Manchester City", "played": 36, "wins": 24, "draws": 6, "losses": 6, "points": 78 }
    ]
  }
}
```
Note the response is keyed by the league (`data.EPL`), not `data.SOCCER`.

**Step 2 — answer.** Sort by `points` desc, format top N.

> EPL standings (36 played):
> 1. Arsenal — 82 pts (25-7-4)
> 2. Manchester City — 78 pts (24-6-6)
> ...

Soccer `player-stats`, `injuries`, and `depth-charts` are **not** documented — if the user asks for them, say so and offer `team-stats` / `player-info` instead.

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
