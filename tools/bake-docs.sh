#!/usr/bin/env bash
#
# Render the specification and the design document into the two pages that
# carry them, /spec/ and /design/.
#
# The text is not kept here. It is fetched from excelano/slipcase, which is the
# authority on the format, and the page it produces is stamped with the exact
# commit it came from — so a reader can tell what revision they are looking at
# and a maintainer can tell when the site has fallen behind. The output is
# committed, so deploying the site needs neither pandoc nor a network.
#
#   tools/bake-docs.sh              # re-render from the tip of main
#   tools/bake-docs.sh --ref v1.0   # from a tag
#   tools/bake-docs.sh --check      # exit 1 if the committed pages are stale
#   SPEC_SRC=~/slipcase/slipcase tools/bake-docs.sh   # from a local checkout
#
# Needs pandoc, and curl unless SPEC_SRC names a checkout.
#
set -euo pipefail

REPO=excelano/slipcase
REF=main
CHECK=0

SITE="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SITE/tools/doc-template.html"

# Each document: source file, output directory, page title, and the one line
# that sits under it. The lede is written here rather than lifted from the
# markdown, because neither document opens with a sentence that works as a
# subtitle and neither should be edited so that it does.
DOCS=(
    "SPEC.md|spec|Slipcase — Specification|What a conformant container is, and what a program that handles one must do."
    "DESIGN.md|design|Slipcase — Design Document|Why each rule is the way it is, and what was considered and rejected."
)

for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        --ref)   echo "--ref takes its value as --ref=<ref>"; exit 1 ;;
        --ref=*) REF="${arg#--ref=}" ;;
        *) echo "Usage: bake-docs.sh [--ref=<git-ref>] [--check]"; exit 1 ;;
    esac
done

command -v pandoc >/dev/null || { echo "pandoc not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Resolve the ref to a commit before fetching anything, so both documents come
# from the same revision even if something lands upstream between the two
# fetches, and so the stamp names a commit rather than a moving branch.
if [ -n "${SPEC_SRC:-}" ]; then
    [ -d "$SPEC_SRC/.git" ] || { echo "SPEC_SRC is not a git checkout: $SPEC_SRC"; exit 1; }
    COMMIT="$(git -C "$SPEC_SRC" rev-parse "$REF")"
    COMMITDATE="$(git -C "$SPEC_SRC" show -s --format=%cd --date=format:'%-d %B %Y' "$COMMIT")"
    if ! git -C "$SPEC_SRC" diff --quiet "$COMMIT" -- SPEC.md DESIGN.md; then
        echo "Refusing to bake: SPEC.md or DESIGN.md is modified in $SPEC_SRC."
        echo "A page stamped with a commit has to hold what that commit says."
        exit 1
    fi
    fetch() { git -C "$SPEC_SRC" show "$COMMIT:$1"; }
else
    command -v curl >/dev/null || { echo "curl not found, and SPEC_SRC is unset"; exit 1; }
    API="https://api.github.com/repos/$REPO/commits/$REF"
    COMMIT="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$API" | sed -n 's/^  "sha": "\([0-9a-f]*\)".*/\1/p' | head -1)"
    [ -n "$COMMIT" ] || { echo "Could not resolve $REPO@$REF"; exit 1; }
    COMMITDATE="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$API" \
        | sed -n 's/.*"date": "\([0-9-]*\)T.*/\1/p' | tail -1)"
    COMMITDATE="$(date -d "$COMMITDATE" '+%-d %B %Y')"
    fetch() { curl -fsSL "https://raw.githubusercontent.com/$REPO/$COMMIT/$1"; }
fi

STALE=0

for doc in "${DOCS[@]}"; do
    IFS='|' read -r SRC SLUG TITLE LEDE <<< "$doc"

    fetch "$SRC" > "$WORK/$SRC"

    # The document's own H1 becomes the page header, so it is dropped from the
    # body rather than rendered twice. Anything else on line one is a change to
    # the source that this script should not paper over.
    case "$(sed -n '1p' "$WORK/$SRC")" in
        '# '*) ;;
        *) echo "$SRC does not begin with an H1"; exit 1 ;;
    esac
    tail -n +2 "$WORK/$SRC" > "$WORK/body.md"

    # A description for search results and link previews: the first line of
    # prose, flattened. Blank lines, headings, tables, quotes and the bold
    # Version/Status pair at the top of SPEC.md are not a sentence.
    DESCRIPTION="$(awk '/^[[:space:]]*$/ || /^[#>*|_-]/ || /^\*\*/ { next }
                        { print; exit }' "$WORK/body.md" \
        | sed 's/\[\([^]]*\)\]([^)]*)/\1/g; s/[`*_]//g; s/"/\&quot;/g')"

    pandoc "$WORK/body.md" \
        --from=gfm \
        --to=html5 \
        --standalone \
        --template="$TEMPLATE" \
        --toc --toc-depth=2 \
        --no-highlight \
        --wrap=none \
        -V "title=$TITLE" \
        -V "pagetitle=$TITLE" \
        -V "lede=$LEDE" \
        -V "description=$DESCRIPTION" \
        -V "slug=$SLUG" \
        -V "docfile=$SRC" \
        -V "commit=$COMMIT" \
        -V "shortcommit=${COMMIT:0:7}" \
        -V "commitdate=$COMMITDATE" \
        > "$WORK/$SLUG.html"

    if [ "$CHECK" = 1 ]; then
        if ! diff -q "$WORK/$SLUG.html" "$SITE/$SLUG/index.html" >/dev/null 2>&1; then
            echo "stale: $SLUG/index.html"
            STALE=1
        else
            echo "current: $SLUG/index.html"
        fi
    else
        mkdir -p "$SITE/$SLUG"
        mv "$WORK/$SLUG.html" "$SITE/$SLUG/index.html"
        echo "wrote $SLUG/index.html from $SRC at ${COMMIT:0:7}"
    fi
done

exit "$STALE"
