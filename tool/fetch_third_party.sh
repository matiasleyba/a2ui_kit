#!/usr/bin/env bash
# Fetches the lucide-react packages that the generator and its tests read
# (port/RULEBOOK.md §0 item 4; the versions are `lucideReactReleases` in
# tool/src/lucide.dart). They go to $A2UI_THIRDPARTY_SRC, else
# third_party_src/ in the package, which git ignores. Needs npm.
#
#   tool/fetch_third_party.sh
#
# The packages are only read as text, never run.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="${A2UI_THIRDPARTY_SRC:-third_party_src}"
VERSIONS=(0.525.0 1.57.0)

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for v in "${VERSIONS[@]}"; do
  dir="$DEST/lucide-react@$v"
  if [ -f "$dir/package.json" ]; then
    echo "lucide-react@$v: already in $DEST"
    continue
  fi
  (cd "$TMP" && npm pack "lucide-react@$v" --silent >/dev/null)
  mkdir -p "$dir"
  tar -xzf "$TMP/lucide-react-$v.tgz" -C "$dir" --strip-components=1
  echo "lucide-react@$v: fetched into $dir"
done
