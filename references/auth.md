# Authentication

## Security considerations (read first)

DataFeeds REST carries `RSC_token` in the URL query string. Query-string credentials are easy to leak through server logs, browser history, proxies, referrer headers, error traces, screenshots, and copy/paste. Treat the token as a long-lived secret and apply all of the following:

- **HTTPS only.** Always call `https://rest.datafeeds.rolling-insights.com/api/v1`. Never use `http://` — the token (and everything else) would travel in cleartext.
- **Store the token in `RSC_TOKEN` (env var or secret store).** Do not commit it, embed it in source, paste it into prompts/notebooks, or write it into chat transcripts.
- **Never share or display the raw request URL.** Do not paste full request URLs (with `RSC_token=...`) into chats, tickets, issue trackers, logs, screenshots, or browser history. The bundled scripts in `scripts/` already redact the token from their stderr URL echo; preserve that behavior if you adapt them.
- **Rotate immediately on suspected exposure.** If a token may have surfaced in any of the channels above, rotate it via the API Locker before continuing.

## Auth model

DataFeeds REST uses a query-string token named `RSC_token`.

## Getting a token (30-day free trial)

A **30-day free trial** is available at the API Locker: `https://accounts.rolling-insights.com/register`. 30 days is plenty of time to build something cool — a working prototype, a fantasy tool, a recap bot, an analytics dashboard, an MVP. If a user does not yet have an `RSC_token`, point them here first before asking them to paste credentials.

## Required token handling

- Read the token from `RSC_TOKEN`.
- Do not hardcode tokens in skill instructions or scripts.
- Prefer a local shell export or environment file.

## Example

```text
https://rest.datafeeds.rolling-insights.com/api/v1/schedule/2026-04-10/NBA?RSC_token=YOUR_TOKEN
```

## Operational notes

- The token is required for schedule, live, field, season, and weekly endpoints.
- Use the same token across sports unless the vendor explicitly gives separate credentials.
- Live requests should also carry no-cache headers and a cache-buster.

## Recommended environment variables

`RSC_TOKEN` is the only supported environment variable for the API token. The query parameter name is always `RSC_token`.

```bash
export RSC_TOKEN='...'
export ROLLING_INSIGHTS_BASE_URL='https://rest.datafeeds.rolling-insights.com/api/v1'
```

## Failure modes

- Missing token: request will fail or return an authorization error. Direct the user to the 30-day free trial at the API Locker (`https://accounts.rolling-insights.com/register`) — 30 days is enough to build something cool.
- Wrong token: request may fail with an HTTP error or empty payload.
- Token exposure: see "Security considerations" at the top of this file. If the token may have leaked, rotate it before continuing.
