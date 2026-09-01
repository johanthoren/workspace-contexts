#!/bin/bash

# A subset of `omarchy plugin validate`, for CI runners that have no Omarchy
# install. The authority is still `omarchy plugin validate .`, run locally; this
# only catches the breakages worth failing a pull request over: unparseable JSON,
# a missing required field, an entry point that does not resolve, and symlinks,
# which the shell refuses to load.

set -euo pipefail

fail() {
  echo "validate-manifest: $*" >&2
  exit 1
}

dir="${1:-.}"
manifest="$dir/manifest.json"

[[ -f $manifest ]] || fail "missing manifest.json in $dir"
jq -e . "$manifest" >/dev/null 2>&1 || fail "manifest.json is not valid JSON"

jq -e '.schemaVersion == 1' "$manifest" >/dev/null \
  || fail "schemaVersion must be the JSON number 1"

for field in id name version kinds entryPoints; do
  jq -e --arg f "$field" 'has($f)' "$manifest" >/dev/null \
    || fail "manifest missing required field '$field'"
done

id=$(jq -r '.id' "$manifest")
[[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "invalid plugin id '$id'"
[[ $id != omarchy.* ]] || fail "plugin id '$id' uses the reserved omarchy.* namespace"

jq -e '(.kinds | type) == "array" and (.kinds | length) > 0' "$manifest" >/dev/null \
  || fail "'kinds' must be a non-empty array"

# Every kind that needs something to load must name where to load it from.
while IFS=: read -r kind entry_point; do
  jq -e --arg k "$kind" '(.kinds | index($k)) != null' "$manifest" >/dev/null 2>&1 || continue
  jq -e --arg e "$entry_point" '.entryPoints | has($e)' "$manifest" >/dev/null \
    || fail "kind '$kind' requires an 'entryPoints.$entry_point' to load"
done <<< "bar:bar
bar-widget:barWidget
menu:menu
overlay:overlay
panel:panel
service:service"

while IFS= read -r entry_point; do
  [[ $entry_point != /* ]] || fail "entry point must be relative: '$entry_point'"
  [[ $entry_point != *".."* ]] || fail "entry point may not contain '..': '$entry_point'"
  [[ -f "$dir/$entry_point" ]] || fail "entry point file not found: '$entry_point'"
done < <(jq -r '.entryPoints[]' "$manifest")

link=$(find "$dir" -name .git -prune -o -type l -print -quit)
[[ -z $link ]] || fail "symlinks are not allowed inside a plugin folder: $link"

echo "validate-manifest: $id ok"
