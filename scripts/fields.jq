# fields.jq — list every field path of a resolved route's response, one per
# line, with its type. Companion to route.jq; reads the object it prints.
#
#   jq -f scripts/route.jq --arg path '/live/{date}/MLB' "${TMPDIR:-/tmp}/spec.json" | jq -r -f scripts/fields.jq
#
# Each line is "<path>  <type>", paths relative to the response body:
#   object property        .name   data.MLB[].game_ID                              string
#   array items            []      data.MLB[]                                      object
#   additionalProperties   .*      data.MLB[].full_box.away_team.quarter_scores.*  integer|null
# anyOf / oneOf / allOf branches are merged into one node: their properties are
# listed together, and a scalar union prints its types joined by "|"
# (number|string). A type list or nullable: true prints "|null" (string|null).
# A {"$circular": ...} or {"$unresolved": ...} marker left by route.jq prints
# as it is. A bare schema (no "response" key) is walked directly.
# Requires jq 1.6 or later. No other dependency, no regex builtins.

def is_marker: type == "object" and (has("$circular") or has("$unresolved"));

def join_path($p; $k): if $p == "" then $k else $p + "." + $k end;

# Order-preserving dedupe.
def uniq: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);

# Two schemas for the same slot: keep one if equal, otherwise union them.
def either($a; $b):
  if $a == null then $b elif $b == null then $a elif $a == $b then $a
  else {anyOf: [$a, $b]} end;

# The type names a plain (combinator-free) schema declares.
def own_types:
  ( if (.type | type) == "array" then .type
    elif (.type | type) == "string" then [.type]
    elif has("properties") or has("additionalProperties") then ["object"]
    elif has("items") then ["array"]
    else [] end )
  + (if .nullable == true then ["null"] else [] end);

# Flatten a schema and its anyOf/oneOf/allOf members into one node:
# {types, properties, items, additional}.
def shape:
  if type != "object" then {types: [], properties: {}, items: null, additional: null}
  elif is_marker then {types: [tojson], properties: {}, items: null, additional: null}
  else
    { types: own_types,
      properties: (.properties // {}),
      items: .items,
      additional: (if (.additionalProperties | type) == "object" then .additionalProperties else null end) }
    as $self
    | reduce ((.anyOf // .oneOf // .allOf // [])[] | shape) as $m ($self;
        .types += $m.types
        | .items = either(.items; $m.items)
        | .additional = either(.additional; $m.additional)
        | .properties = reduce ($m.properties | to_entries[]) as $e (.properties;
            .[$e.key] = either(.[$e.key]; $e.value)))
  end;

# "string|null": unique names, null last, "any" when nothing is declared.
def type_label:
  (.types | uniq) as $t
  | ($t | map(select(. != "null"))) + (if any($t[]; . == "null") then ["null"] else [] end)
  | if length == 0 then "any" else join("|") end;

def walk_fields($path):
  shape as $s
  | (if $path == "" then empty else "\($path)  \($s | type_label)" end),
    ($s.properties | to_entries[] | . as $e | $e.value | walk_fields(join_path($path; $e.key))),
    (if $s.items != null then $s.items | walk_fields($path + "[]") else empty end),
    (if $s.additional != null then $s.additional | walk_fields(join_path($path; "*")) else empty end);

(if type == "object" and has("response") then .response else . end) | walk_fields("")
