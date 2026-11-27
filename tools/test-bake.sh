#!/usr/bin/env bash
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)

set -euo pipefail

: "${SPEC_SRC:?SPEC_SRC must name a checkout of excelano/slipcase}"
: "${PROFILES_SRC:?PROFILES_SRC must name a checkout of excelano/slipcase-profiles}"

SITE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "ok: $*"; }

PROFILE_PAGES=(
    profiles/framework
    profiles/conventions
    profiles/design
    profiles/records
    profiles/records/design
    profiles/dublin
    profiles/dublin/design
)

SPEC_COMMIT="$(grep -o 'excelano/slipcase/blob/[0-9a-f]\{40\}' "$SITE/spec/index.html" | head -1 | sed 's#.*/##')"
[ -n "$SPEC_COMMIT" ] || fail "no commit stamp in spec/index.html"

printf '%s\n' '[c](../CONVENTIONS.md#3-dates) [s](SPEC.md#3-retention-schedules) [f](../FRAMEWORK.md) [l](../LICENSE) [e](examples/register/README.md) [x](https://example.com/) [a](#top)' > "$WORK/links.md"
LINKS="$(pandoc "$WORK/links.md" --from=gfm --to=html5 --lua-filter="$SITE/tools/profile-links.lua" \
    -M profile-doc=records/DESIGN.md -M profile-commit=abc123)"
for want in 'href="/profiles/conventions/#3-dates"' 'href="/profiles/records/#3-retention-schedules"' 'href="/profiles/framework/"' \
        'href="https://github.com/excelano/slipcase-profiles/blob/abc123/LICENSE"' \
        'href="https://github.com/excelano/slipcase-profiles/blob/abc123/records/examples/register/README.md"' \
        'href="https://example.com/"' 'href="#top"'; do
    grep -qF "$want" <<< "$LINKS" || fail "profile-links.lua: no $want in: $LINKS"
done
pass "relative links in profile documents are rewritten"

cp -a "$SITE" "$WORK/site"
"$WORK/site/tools/bake-docs.sh" --ref="$SPEC_COMMIT" > "$WORK/bake.log" 2>&1 \
    || { cat "$WORK/bake.log"; fail "bake-docs.sh exited nonzero"; }
pass "baked"

for page in spec design; do
    cmp -s "$SITE/$page/index.html" "$WORK/site/$page/index.html" \
        || fail "$page/index.html differs from the committed page"
done
pass "Slipcase pages byte-identical"

for page in "${PROFILE_PAGES[@]}"; do
    [ -s "$WORK/site/$page/index.html" ] || fail "$page/index.html missing"
done
pass "profile pages present"

SPEC_DATE="$(TZ=UTC git -C "$SPEC_SRC" show -s --date=format-local:'%-d %B %Y' --format=%cd "$SPEC_COMMIT")"
grep -q "<code>${SPEC_COMMIT:0:7}</code>, $SPEC_DATE\." "$WORK/site/spec/index.html" \
    || fail "spec page date is not the commit's UTC date ($SPEC_DATE)"
pass "stamp dates are UTC"

for page in "${PROFILE_PAGES[@]}"; do
    f="$WORK/site/$page/index.html"
    relative="$(grep -o 'href="[^"]*"' "$f" | grep -v -E 'href="(https?://|/|#)' | head -1 || true)"
    [ -z "$relative" ] || fail "$page has a relative href: $relative"
    if grep -o 'href="/[^"]*"' "$f" | grep -q -E '\.md(#|")|LICENSE'; then
        fail "$page links a repository file as a site path"
    fi
    if grep -o '<a [^>]*href="https://github.com[^"]*"[^>]*>' "$f" | grep -v -q 'target="_blank"'; then
        fail "$page has a GitHub link that opens in place"
    fi
done
pass "no dead or in-place links in profile pages"

"$WORK/site/tools/bake-docs.sh" --ref="$SPEC_COMMIT" --check > "$WORK/check.log" 2>&1 \
    || { cat "$WORK/check.log"; fail "--check after a bake"; }
pass "--check current after a bake"

echo "all passed"
