#!/usr/bin/env bash
# Synthetic-fixture check for scripts/route.jq: nested refs, an array of refs, a oneOf, a ref
# with siblings, a ref-with-enum parameter, a cycle, case-insensitive lookup, an unknown path.
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=$(mktemp) && trap 'rm -f "$fixture"' EXIT
cat > "$fixture" <<'JSON'
{"openapi":"3.1.0","paths":{"/thing/{id}/X":{"get":{"summary":"S","description":"D",
 "parameters":[{"name":"id","in":"path","required":true,"schema":{"$ref":"#/components/schemas/Id"}}],
 "responses":{"200":{"content":{"application/json":{"schema":{"$ref":"#/components/schemas/Top"}}}}}}}},
 "components":{"schemas":{"Id":{"type":"string","enum":["a","b"]},
 "Top":{"type":"object","properties":{"list":{"type":"array","items":{"$ref":"#/components/schemas/Leaf"}},
  "pick":{"oneOf":[{"$ref":"#/components/schemas/Leaf","description":"kept"},{"$ref":"#/components/schemas/Node"}]}}},
 "Leaf":{"type":"object","properties":{"v":{"$ref":"#/components/schemas/Id"}}},
 "Node":{"type":"object","properties":{"next":{"$ref":"#/components/schemas/Node"}}}}}}
JSON
out=$(jq -f scripts/route.jq --arg path '/thing/{id}/x' "$fixture")   # lower-case x: case-insensitive match
check() { jq -e "$1" <<<"$out" >/dev/null || { echo "route-test: FAIL: $1"; exit 1; }; }
check '.path == "/thing/{id}/X" and .summary == "S"'
check '[.. | objects | has("$ref")] | any | not'                              # no $ref survives
check '.parameters[0].schema.enum == ["a","b"]'                               # parameter ref, enum kept
check '.response.properties.list.items.properties.v.type == "string"'         # array of refs, nested ref
check '.response.properties.pick.oneOf[0] | .description == "kept" and .type == "object"'  # oneOf + siblings
check '.response.properties.pick.oneOf[1].properties.next == {"$circular": "#/components/schemas/Node"}'
err=$(jq -f scripts/route.jq --arg path '/thing/{id}/Y' "$fixture" 2>&1 >/dev/null) && { echo "route-test: FAIL: unknown path exited 0"; exit 1; }
grep -q '/thing/{id}/X' <<<"$err" || { echo "route-test: FAIL: closest match not named"; exit 1; }
echo "route-test: OK"
