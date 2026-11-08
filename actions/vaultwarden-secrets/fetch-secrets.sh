#!/usr/bin/env bash
# Run by action.yml, once per deploy, on the runner: logs in to Vaultwarden as the deploy-bot user with the Bitwarden CLI
# and writes one <name>.env per file of the secrets map's <TARGET> into $OUT_DIR, for the caller's deploy to stage.
#
# Environment (set by action.yml):
#   MAP          Path to the secrets map: {"<target>": {"<file>.env": {"<VARIABLE>": "<item name>"}}}
#   TARGET       Which key of the map to fetch (dev or prod)
#   COLLECTION   The Vaultwarden collection the target's items are in, e.g. countdown-server/dev. Items are named by their
#                bare variable, so the same name can be a different item per collection, and an item that several projects
#                share is put in each one's collection. The vault's collections are all under its "Default collection", so
#                the name is matched by its end.
#   OUT_DIR      A new directory for the files
#   BW_CLIENTID, BW_CLIENTSECRET   The bot's API key
#   BW_PASSWORD  Its master password, which `bw unlock` needs even after an API-key login
#   BW_SERVER    The Vaultwarden server
#
# One `bw list items` reads every item the bot can see (decrypted once), and jq picks the values out of that, instead of
# a `bw get` per secret, each of which starts the CLI again and searches the vault again. The times of the phases are
# printed, to see what is slow.
set -euo pipefail

: "${MAP:?}" "${TARGET:?}" "${COLLECTION:?}" "${OUT_DIR:?}" "${BW_SERVER:?}"
: "${BW_CLIENTID:?}" "${BW_CLIENTSECRET:?}" "${BW_PASSWORD:?}"
map="$MAP"
target="$TARGET"
out="$OUT_DIR"

lap_start=$SECONDS
lap() { echo "  $1: $((SECONDS - lap_start))s"; lap_start=$SECONDS; }

# The CLI's state (its tokens) in a directory of its own, removed at the end, with the decrypted items next to it.
BITWARDENCLI_APPDATA_DIR="$(mktemp -d)"
export BITWARDENCLI_APPDATA_DIR BW_NOINTERACTION=true
trap 'bw logout >/dev/null 2>&1 || true; rm -rf "$BITWARDENCLI_APPDATA_DIR"' EXIT
items="$BITWARDENCLI_APPDATA_DIR/items.json"
# The CLI makes up a random device id (global_applicationId_appId) in a fresh state directory, so every run would be a
# new device to Vaultwarden, which emails "new device logged in" each time. A fixed one makes it the same device.
cp "$(dirname "$0")/bitwarden-cli/data.json" "$BITWARDENCLI_APPDATA_DIR/data.json"

jq -e --arg t "$target" '.[$t]' "$map" >/dev/null || { echo "the secrets map $map has no target $target" >&2; exit 1; }

bw config server "$BW_SERVER" >/dev/null
bw login --apikey >/dev/null
lap "login"
BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
export BW_SESSION
lap "unlock"

umask 077
list_items() { bw list items > "$items"; }
list_items
lap "list items ($(jq length "$items") readable)"

collection="$COLLECTION"
collection_id="$(bw list collections | jq -er --arg c "$collection" '[.[] | select(.name == $c or (.name | endswith("/" + $c)))] | if length == 1 then .[0].id else error("no single collection named \($c)") end')"

# The value of the one item with exactly this name in the target's collection; fails (with the reason) if there are
# none or several.
lookup() {
  jq -r --arg n "$1" --arg c "$collection_id" '[.[] | select(.name == $n and ((.collectionIds // []) | index($c)))] as $m
    | if ($m | length) == 1 then ($m[0].login.password // "")
      else error("\($m | length) items are named \($n) in \($c)") end' "$items" 2>&1 | sed 's/^jq: error (at [^)]*): //'
}

# Reads every entry of the target into $out, or returns 1 with $problem set.
read_all() {
  rm -rf "$out"
  mkdir "$out"
  count=0
  problem=
  local file key item value
  while IFS=$'\t' read -r file key item; do
    if ! value="$(lookup "$item" 2>&1)"; then problem="$item: $value"; return 1; fi
    if [ -z "$value" ]; then problem="$item: empty"; return 1; fi
    # Keep the value out of the job's log, should something print it.
    while IFS= read -r line; do [ -n "$line" ] && echo "::add-mask::$line"; done <<< "$value"
    printf '%s=%s\n' "$key" "$value" >> "$out/$file"
    count=$((count + 1))
  done < <(jq -r --arg t "$target" '.[$t] | to_entries[] | .key as $f | .value | to_entries[] | [$f, .key, .value] | @tsv' "$map")
}

if ! read_all; then
  # An item added to the vault since the CLI last synced (login syncs once): sync and look again before giving up.
  echo "Not all there ($problem); syncing and trying again"
  bw sync >/dev/null
  list_items
  lap "sync and list again"
  if ! read_all; then
    # Names only, never values: what this user can see, to tell a missing item from a missing membership or grant.
    {
      echo "Can't read $problem"
      echo "This user sees $(bw list organizations | jq length) organizations, collections [$(bw list collections | jq -r '[.[].name] | join(", ")')]"
      echo "and $(jq length "$items") items, of which those named ${problem%%:*}: [$(jq -r --arg n "${problem%%:*}" '[.[] | select(.name == $n) | "\(.name) in \(.collectionIds | length) collections"] | join(", ")' "$items")]"
    } >&2
    exit 1
  fi
fi
lap "read ${count} values"

echo "Fetched $count secrets for $target into $(find "$out" -name '*.env' | wc -l | tr -d ' ') files"
