# The published OpenAPI spec

The REST contract lives in one public file (no token needed, about 800 KB, 84 routes):
`https://docs.datafeeds.rolling-insights.com/spec.json`

## The three commands

```bash
curl -s https://docs.datafeeds.rolling-insights.com/spec.json -o /tmp/spec.json
jq '.paths | keys' /tmp/spec.json
jq -f scripts/route.jq --arg path '/live/{date}/NBA' /tmp/spec.json
```

Note the date you downloaded it; the spec carries no per-deploy version yet.

`scripts/route.jq` ships with this skill (path relative to the skill directory; jq 1.6 or later, nothing else).
It prints one object: `path`, `summary`, `description`, `parameters` (name, `in`, required, description,
schema with enums) and `response`, the 200 JSON schema with every `$ref` resolved. Redirect it to a file
(`> /tmp/route.json`) when the schema is big; the largest live box-score route is about 37 KB.

## Pick the route before resolving it

Read a candidate's summary and description first; resolve only the one you will call:

```bash
jq --arg p '/live/{date}/NBA' '.paths[$p].get | {summary, description}' /tmp/spec.json
```

An unknown path fails with the closest matching paths on stderr. Paths are matched as written in the
spec, braces included (a case-insensitive match is tried second).

## Two rules

1. Never read the whole file into context. List the paths, read one route's summary and description,
   resolve that one route.
2. The MCP's tool names, arguments and responses say nothing about the REST contract. Only the spec does.
