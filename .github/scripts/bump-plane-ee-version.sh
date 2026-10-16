#!/usr/bin/env bash
# Usage: bump-plane-ee-version.sh vX.Y.Z
set -euo pipefail

NEW="${1:?usage: $0 vX.Y.Z}"
CHART_DIR="${CHART_DIR:-charts/plane-enterprise}"

if [[ ! "$NEW" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::'$NEW' is not a stable release version (expected vX.Y.Z)"
  exit 1
fi

output() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "$1=$2" >> "$GITHUB_OUTPUT" || true; }

OLD=$(awk '/^planeVersion:/ {print $2; exit}' "$CHART_DIR/values.yaml")
[ -n "$OLD" ] || { echo "::error::planeVersion not found in $CHART_DIR/values.yaml"; exit 1; }
output old_version "$OLD"
output new_version "$NEW"

if [ "$OLD" = "$NEW" ]; then
  echo "$CHART_DIR already on $NEW, nothing to do"
  output changed false
  exit 0
fi

# awk with literal (non-regex) replacement, since versions contain dots.
rewrite() {
  local file="$1" prog="$2"
  awk -v old="$OLD" -v new="$NEW" '
    function repl(s,   i, out) {
      out = ""
      while ((i = index(s, old)) > 0) { out = out substr(s, 1, i - 1) new; s = substr(s, i + length(old)) }
      return out s
    }
    '"$prog" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

rewrite "$CHART_DIR/values.yaml" '/^planeVersion:/ { $0 = "planeVersion: " new } { print }'

rewrite "$CHART_DIR/questions.yml" '
  /^- variable: planeVersion$/ { inblock = 1 }
  inblock && /^  default:/ { $0 = "  default: " new; inblock = 0 }
  { print }'

CHART_VERSION=$(awk '/^version:/ {print $2; exit}' "$CHART_DIR/Chart.yaml")
NEXT_CHART_VERSION=$(echo "$CHART_VERSION" | awk -F. '{printf "%d.%d.%d", $1, $2, $3 + 1}')
awk -v cv="$NEXT_CHART_VERSION" -v av="${NEW#v}" '
  /^version:/ { $0 = "version: " cv }
  /^appVersion:/ { $0 = "appVersion: \"" av "\"" }
  { print }' "$CHART_DIR/Chart.yaml" > "$CHART_DIR/Chart.yaml.tmp"
mv "$CHART_DIR/Chart.yaml.tmp" "$CHART_DIR/Chart.yaml"
output chart_version "$NEXT_CHART_VERSION"

README_HITS=$(grep -cE "(planeVersion|PLANE_VERSION).*${OLD//./\\.}" "$CHART_DIR/README.md" || true)
rewrite "$CHART_DIR/README.md" '/planeVersion|PLANE_VERSION/ { $0 = repl($0) } { print }'

fail=0
if [ "$README_HITS" -ne 3 ]; then
  echo "::error::expected 3 planeVersion references to $OLD in README.md, found $README_HITS"
  fail=1
fi
for f in values.yaml questions.yml; do
  if grep -qF "$OLD" "$CHART_DIR/$f"; then
    echo "::error::$CHART_DIR/$f still references $OLD"
    fail=1
  fi
  if ! grep -qF "$NEW" "$CHART_DIR/$f"; then
    echo "::error::$CHART_DIR/$f was not updated to $NEW"
    fail=1
  fi
done
[ "$fail" -eq 0 ] || exit 1

echo "Bumped $CHART_DIR: planeVersion $OLD -> $NEW, chart $CHART_VERSION -> $NEXT_CHART_VERSION"
output changed true
