#!/usr/bin/env bash
#
# Build the 1200x630 social card served as /img/og-card.png, the image that
# appears when a link to this site is pasted into a chat, a post, or a message.
#
# Build-only tooling: tools/ is excluded from updatesite, so this lives with the
# repo and is never served. Needs ImageMagick 7 (magick), rsvg-convert, and the
# DejaVu fonts. Run it after changing the icon or the one-line description; the
# PNG it writes is committed, so nobody needs these to deploy the site.
#
# Author: David M. Anderson. Built with AI assistance (Claude, Anthropic).
#
set -euo pipefail

SITE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SITE/img/og-card.png"

BOLD=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
REG=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
for f in "$BOLD" "$REG"; do [ -f "$f" ] || { echo "missing font: $f" >&2; exit 1; }; done

# The brand: the case in slate blue, the card in ochre. Same pair brand.css
# carries, so the card and the page a reader lands on agree.
CASE_DEEP="#29405f"
OCHRE="#d9a45f"
TEXT="#f4f6fa"
DIM="#c3d0e2"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rsvg-convert -w 260 -h 260 -o "$TMP/icon.png" "$SITE/img/slipcase-icon.svg"

magick -size 1200x630 "xc:$CASE_DEEP" \
    -fill "$OCHRE" -draw 'rectangle 0,614 1200,630' \
    "$TMP/icon.png" -geometry +100+185 -composite \
    -font "$BOLD" -pointsize 96 -fill "$TEXT" \
    -annotate +430+300 'Slipcase' \
    -font "$REG" -pointsize 40 -fill "$DIM" \
    -annotate +432+365 'A container file format that' \
    -annotate +432+415 'attaches metadata to a file.' \
    -font "$BOLD" -pointsize 32 -fill "$OCHRE" \
    -annotate +432+500 'slipcaseformat.org' \
    "$OUT"

echo "wrote ${OUT#"$SITE"/} ($(identify -format '%wx%h, %b' "$OUT"))"
