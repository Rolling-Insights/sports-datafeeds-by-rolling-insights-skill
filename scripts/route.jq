# route.jq — resolve one route of the DataFeeds OpenAPI spec: its request
# parameters and its 200 application/json response, with every $ref expanded.
#
#   curl -s https://docs.datafeeds.rolling-insights.com/spec.json -o /tmp/spec.json
#   jq '.paths | keys' /tmp/spec.json
#   jq -f scripts/route.jq --arg path '/live/{date}/NBA' /tmp/spec.json
#
# Output: one object {path, summary, description, parameters, response}.
#   parameters: [{name, in, required, description, schema}] with schema resolved
#   response:   the 200 application/json schema, nested refs, arrays of refs and
#               anyOf/oneOf/allOf branches all expanded in place
# No "$ref" survives in the output. A reference back into a schema that is
# already being expanded becomes {"$circular": "<ref>"} instead of recursing;
# a reference that points nowhere becomes {"$unresolved": "<ref>"}.
# The path is matched exactly as written in the spec (braces included); if
# that fails, a case-insensitive match on the whole path is tried. An unknown
# path exits 1 and names the closest spec paths on stderr.
# Requires jq 1.6 or later. No other dependency, no regex builtins.

# "#/components/schemas/X" -> ["components", "schemas", "X"] (RFC 6901 unescape)
def pointer_path:
  ltrimstr("#/") | split("/")
  | map(split("~1") | join("/") | split("~0") | join("~"));

# Follow a pointer through objects only; null when it points nowhere. Deliberately
# no try/catch: under jq 1.6 a try upstream of any/first (which exit early via
# label/break) swallows their internal break and yields null.
def lookup($keys):
  reduce $keys[] as $k (.; if type == "object" then .[$k] else null end);

# Expand every $ref below ".". $root is the whole document; $chain lists the
# refs currently being expanded, so a ref already on it is a cycle.
def resolve($root; $chain):
  if type == "object" then
    if has("$ref") then
      .["$ref"] as $r
      | (del(.["$ref"]) | resolve($root; $chain)) as $siblings
      | ( if any($chain[]; . == $r) then {"$circular": $r}
          elif ($r | startswith("#/")) | not then {"$unresolved": $r}
          else ($root | lookup($r | pointer_path)) as $target
            | if $target == null then {"$unresolved": $r}
              else $target | resolve($root; $chain + [$r]) end
          end
        ) + $siblings
    else map_values(resolve($root; $chain))
    end
  elif type == "array" then map(resolve($root; $chain))
  else . end;

# Path segments, upper-cased, for fuzzy matching: "/live/{date}/NBA" -> ["LIVE","{DATE}","NBA"]
def segments: split("/") | map(select(length > 0) | ascii_upcase);

# The spec paths sharing the most segments with $wanted (ties: closest length, then name).
def closest($wanted; $known):
  ($wanted | segments) as $w
  | [ $known[] | . as $p | ($p | segments) as $s
      | { p: $p,
          shared: ([ $w[] | select(. as $x | any($s[]; . == $x)) ] | length),
          gap: ((($s | length) - ($w | length)) | length) } ]
  | map(select(.shared > 0))
  | sort_by(-.shared, .gap, .p) | .[:5] | map(.p);

. as $root
| ( $ARGS.named.path
    // ("usage: jq -f scripts/route.jq --arg path '/live/{date}/NBA' spec.json\n" | halt_error(2))
  ) as $wanted
| if ($root.paths | type) != "object" then
    "route.jq: the input has no .paths object; is it the OpenAPI spec?\n" | halt_error(1)
  else . end
| ($wanted | if startswith("/") then . else "/" + . end) as $wanted
| ($root.paths | keys) as $known
| ( if $root.paths | has($wanted) then $wanted
    else first($known[] | select(ascii_upcase == ($wanted | ascii_upcase))) // null
    end ) as $key
| if $key == null then
    ( "route.jq: no route \($wanted) in the spec."
      + ( closest($wanted; $known)
          | if length == 0 then " List them with: jq '.paths | keys' spec.json"
            else " Closest matches:\n" + (map("  " + .) | join("\n")) end )
      + "\n" ) | halt_error(1)
  else
    $root.paths[$key] as $item
    | ( $item.get
        // ("route.jq: \($key) has no GET operation in the spec.\n" | halt_error(1)) ) as $op
    | ($op.responses["200"] | resolve($root; [])) as $ok
    | { path: $key,
        summary: $op.summary,
        description: $op.description,
        parameters: [ (($item.parameters // []) + ($op.parameters // []))[]
                      | resolve($root; [])
                      | { name, in, required: (.required // false), description, schema } ],
        response: ($ok.content["application/json"].schema // null) }
  end
