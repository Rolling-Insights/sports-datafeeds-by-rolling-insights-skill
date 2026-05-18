# Troubleshooting

## 304 responses

Cause: the live feed or intermediary cache thinks you already have the latest version.

Fix:
- add `Cache-Control: no-cache, no-store`
- add `Pragma: no-cache`
- add a fresh timestamp cache buster
- retry once

## Missing data

Common causes:
- wrong sport code
- wrong date format
- event has not started yet
- sport coverage is sparse for the requested event
- PGA player or field data can be limited for some tours or lesser-covered events

Fix:
- verify the schedule endpoint first
- confirm the event ID or game ID
- retry live after schedule confirmation

## Invalid date formats

Symptoms:
- plain-text error message
- HTTP error
- empty payload

Fix:
- use `YYYY-MM-DD` for standard schedule/live calls
- use the exact year or `YYYY_N` format where the doc requires it
- check endpoint ordering carefully

## Sparse sports coverage

Some sports or events may be partially covered or have fewer live details than others.

Fix:
- parse defensively
- check for missing nested fields before accessing them
- expect nulls, empty arrays, or reduced player detail

## GraphQL note

GraphQL exists for some sports in Rolling Insights, but this skill intentionally excludes it from the first version. Use REST only unless a later revision explicitly adds GraphQL support.

## Final sanity checks

- token present
- sport code exact
- date format valid
- live requests cache-busted
- payload JSON parsed successfully
