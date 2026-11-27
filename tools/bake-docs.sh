#!/usr/bin/env bash
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bake-docs.sh [--ref=<git-ref>] [--check]

Render the documents this site carries from the repositories that are their
authority, each page stamped with the repository and commit it came from. The
output is committed, so a deploy needs neither pandoc nor a network.

  --ref=<ref>   the excelano/slipcase ref for /spec/ and /design/ (default main);
                the profile pages bake from the tags in the document list
  --check       exit 1 if any committed page differs from a fresh bake

  SPEC_SRC=<dir>      read excelano/slipcase from a local checkout
  PROFILES_SRC=<dir>  read excelano/slipcase-profiles from a local checkout

Needs pandoc, and curl for any repository without a local checkout.
EOF
}

SLIPCASE_REF=main
CHECK=0

SITE="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SITE/tools/doc-template.html"

RECORDS_VERSIONS_CURRENT='Versions: <a href="/profiles/records/1.0/">1.0</a> (current).'
RECORDS_VERSIONS_FROZEN='This is version 1.0, kept as it was released. The current version is at <a href="/profiles/records/">/profiles/records/</a>.'
CORE_DRAFT='Version 1.0, a draft: it changes without its version number moving until it is declared final.'

DOCS=(
    "slipcase|-|SPEC.md|spec|Slipcase — Specification|What a conformant container is, and what a program that handles one must do.|"
    "slipcase|-|DESIGN.md|design|Slipcase — Design Document|Why each rule is the way it is, and what was considered and rejected.|"
    "slipcase-profiles|framework-v1.0|FRAMEWORK.md|profiles/framework|Slipcase Profiles — Framework|What every profile has in common: the table it owns, the directory its members live under, and how it is versioned.|"
    "slipcase-profiles|framework-v1.0|CONVENTIONS.md|profiles/conventions|Slipcase Profiles — Shared Conventions|How every profile writes an identifier, an agent, a hash, a date, and a log that shows when it has been edited.|"
    "slipcase-profiles|framework-v1.0|DESIGN.md|profiles/design|Slipcase Profiles — Design Document|Why each rule of the framework and the conventions is drawn where it is.|"
    "slipcase-profiles|records-v1.0|records/SPEC.md|profiles/records|Slipcase Records Profile — Specification|A container as a managed record: identity, retention, holds, history, and the register of its destruction.|$RECORDS_VERSIONS_CURRENT"
    "slipcase-profiles|records-v1.0|records/SPEC.md|profiles/records/1.0|Slipcase Records Profile 1.0 — Specification|A container as a managed record: identity, retention, holds, history, and the register of its destruction.|$RECORDS_VERSIONS_FROZEN"
    "slipcase-profiles|records-v1.0|records/DESIGN.md|profiles/records/design|Slipcase Records Profile — Design Document|Why each rule of the Records Profile is the way it is, and what was considered and rejected.|"
    "slipcase-profiles|main|core/SPEC.md|profiles/core|Slipcase Core Profile — Specification|Dublin Core metadata for Slipcase containers.|$CORE_DRAFT"
    "slipcase-profiles|main|core/DESIGN.md|profiles/core/design|Slipcase Core Profile — Design Document|Why each rule of the Core Profile is the way it is, and what was considered and rejected.|$CORE_DRAFT"
)

for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        --ref)   echo "--ref takes its value as --ref=<ref>"; exit 1 ;;
        --ref=*) SLIPCASE_REF="${arg#--ref=}" ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

command -v pandoc >/dev/null || { echo "pandoc not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

local_src() {
    case "$1" in
        slipcase)          echo "${SPEC_SRC:-}" ;;
        slipcase-profiles) echo "${PROFILES_SRC:-}" ;;
    esac
}

authority() {
    [ "$2" = "profiles/records/1.0" ] && {
        echo "This page is version 1.0 as it was released: where this page and that commit differ, the commit is right and this page is stale."
        return
    }
    case "$1" in
        slipcase)          echo "The repository is the authority on the format: where this page and it differ, it is right and this page is stale." ;;
        slipcase-profiles) echo "The repository is the authority on profiles: where this page and it differ, it is right and this page is stale." ;;
    esac
}

dedicated() {
    case "$1" in
        slipcase)          echo "The specification" ;;
        slipcase-profiles) echo "This document" ;;
    esac
}

declare -A COMMIT_OF DATE_OF

resolve() {
    local repo="$1" ref="$2" key="$1@$2" src
    [ -n "${COMMIT_OF[$key]:-}" ] && return
    src="$(local_src "$repo")"
    if [ -n "$src" ]; then
        [ -d "$src/.git" ] || { echo "not a git checkout: $src"; exit 1; }
        COMMIT_OF[$key]="$(git -C "$src" rev-parse "$ref^{commit}")"
        DATE_OF[$key]="$(TZ=UTC git -C "$src" show -s --format=%cd --date=format-local:'%-d %B %Y' "${COMMIT_OF[$key]}")"
    else
        command -v curl >/dev/null || { echo "curl not found, and no local checkout of $repo"; exit 1; }
        local api="https://api.github.com/repos/excelano/$repo/commits/$ref" json
        json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api")"
        COMMIT_OF[$key]="$(sed -n 's/^  "sha": "\([0-9a-f]*\)".*/\1/p' <<< "$json" | head -1)"
        [ -n "${COMMIT_OF[$key]}" ] || { echo "Could not resolve excelano/$repo@$ref"; exit 1; }
        DATE_OF[$key]="$(date -d "$(sed -n 's/.*"date": "\([0-9-]*\)T.*/\1/p' <<< "$json" | tail -1)" '+%-d %B %Y')"
    fi
}

fetch() {
    local repo="$1" commit="$2" file="$3" src
    src="$(local_src "$repo")"
    if [ -n "$src" ]; then
        git -C "$src" show "$commit:$file"
    else
        curl -fsSL "https://raw.githubusercontent.com/excelano/$repo/$commit/$file"
    fi
}

for doc in "${DOCS[@]}"; do
    IFS='|' read -r REPO REF SRC SLUG TITLE LEDE VERSIONS <<< "$doc"
    [ "$REF" = "-" ] && REF="$SLIPCASE_REF"
    resolve "$REPO" "$REF"
    COMMIT="${COMMIT_OF[$REPO@$REF]}"
    COMMITDATE="${DATE_OF[$REPO@$REF]}"

    src="$(local_src "$REPO")"
    if [ -n "$src" ] && [ "$(git -C "$src" rev-parse HEAD)" = "$COMMIT" ] \
        && ! git -C "$src" diff --quiet HEAD -- "$SRC"; then
        echo "Note: $SRC is modified in $src; baking ${COMMIT:0:7}, which does not include those edits." >&2
    fi

    fetch "$REPO" "$COMMIT" "$SRC" > "$WORK/source.md"

    case "$(sed -n '1p' "$WORK/source.md")" in
        '# '*) ;;
        *) echo "$REPO/$SRC does not begin with an H1"; exit 1 ;;
    esac
    tail -n +2 "$WORK/source.md" > "$WORK/body.md"

    DESCRIPTION="$(awk '/^[[:space:]]*$/ || /^[#>*|_-]/ || /^\*\*/ { next }
                        { print; exit }' "$WORK/body.md" \
        | sed 's/\[\([^]]*\)\]([^)]*)/\1/g; s/[`*_]//g; s/"/\&quot;/g')"

    FILTERS=()
    [ "$REPO" = "slipcase-profiles" ] && FILTERS+=(--lua-filter="$SITE/tools/profile-links.lua")
    FILTERS+=(--lua-filter="$SITE/tools/external-links.lua")

    pandoc "$WORK/body.md" \
        --from=gfm \
        --to=html5 \
        --standalone \
        --template="$TEMPLATE" \
        "${FILTERS[@]}" \
        --toc --toc-depth=2 \
        --no-highlight \
        --wrap=none \
        -M "profile-doc=$SRC" \
        -M "profile-commit=$COMMIT" \
        -V "title=$TITLE" \
        -V "pagetitle=$TITLE" \
        -V "lede=$LEDE" \
        -V "versions=$VERSIONS" \
        -V "description=$DESCRIPTION" \
        -V "slug=$SLUG" \
        -V "repo=excelano/$REPO" \
        -V "authority=$(authority "$REPO" "$SLUG")" \
        -V "dedicated=$(dedicated "$REPO")" \
        -V "docfile=$SRC" \
        -V "commit=$COMMIT" \
        -V "shortcommit=${COMMIT:0:7}" \
        -V "commitdate=$COMMITDATE" \
        > "$WORK/page.html"

    if [ "$CHECK" = 1 ]; then
        if cmp -s "$WORK/page.html" "$SITE/$SLUG/index.html"; then
            echo "current: $SLUG/index.html"
        else
            echo "stale: $SLUG/index.html"
            STALE=1
        fi
    else
        mkdir -p "$SITE/$SLUG"
        mv "$WORK/page.html" "$SITE/$SLUG/index.html"
        echo "wrote $SLUG/index.html from $REPO/$SRC at ${COMMIT:0:7}"
    fi
done

exit "${STALE:-0}"
