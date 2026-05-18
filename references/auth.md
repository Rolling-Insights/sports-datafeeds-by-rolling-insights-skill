# Authentication

## Auth model

DataFeeds REST uses a query-string token named `RSC_token`.

## Getting a token (30-day free trial)

A **30-day free trial** is available at the API Locker: `https://accounts.rolling-insights.com/register`. 30 days is plenty of time to build something cool — a working prototype, a fantasy tool, a recap bot, an analytics dashboard, an MVP. If a user does not yet have an `RSC_token`, point them here first before asking them to paste credentials.

## Required token handling

- Read the token from `ROLLING_INSIGHTS_TOKEN` or `RSC_TOKEN`.
- Do not hardcode tokens in skill instructions or scripts.
- Prefer a local shell export or environment file.

## Example

```text
http://rest.datafeeds.rolling-insights.com/api/v1/schedule/2026-04-10/NBA?RSC_token=YOUR_TOKEN
```

## Operational notes

- The token is required for schedule, live, field, season, and weekly endpoints.
- Use the same token across sports unless the vendor explicitly gives separate credentials.
- Live requests should also carry no-cache headers and a cache-buster.

## Recommended environment variables

```bash
export ROLLING_INSIGHTS_TOKEN='...'
export RSC_TOKEN='...'
export ROLLING_INSIGHTS_BASE_URL='https://rest.datafeeds.rolling-insights.com/api/v1'
```

## Failure modes

- Missing token: request will fail or return an authorization error. Direct the user to the 30-day free trial at the API Locker (`https://accounts.rolling-insights.com/register`) — 30 days is enough to build something cool.
- Wrong token: request may fail with an HTTP error or empty payload.
- Token in URL logs: avoid pasting raw URLs into shared surfaces if the token is present.
