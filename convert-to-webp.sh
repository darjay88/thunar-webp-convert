#!/usr/bin/env bash
# =============================================================================
#  convert-to-webp.sh
#  Converts one or more images to WebP at 800px wide, retaining aspect ratio.
#  Usage: convert-to-webp.sh <image1> [image2] ...
# =============================================================================

set -euo pipefail

# ---------- configuration ----------------------------------------------------
TARGET_WIDTH=800
QUALITY=85          # WebP quality (1-100); 85 is a good balance
OUTPUT_SUFFIX=""    # leave empty to place output beside the source file
                    # e.g. set to "-webp" → "photo-webp.webp"
# -----------------------------------------------------------------------------

# Dependency check
if ! command -v cwebp &>/dev/null; then
    notify-send -u critical "convert-to-webp" \
        "❌ 'cwebp' not found.\nInstall it with:  sudo pacman -S libwebp-utils" 2>/dev/null || true
    echo "ERROR: 'cwebp' is not installed. Run: sudo pacman -S libwebp-utils" >&2
    exit 1
fi

if ! command -v convert &>/dev/null; then
    notify-send -u critical "convert-to-webp" \
        "❌ 'convert' (ImageMagick) not found.\nInstall it with:  sudo pacman -S imagemagick" 2>/dev/null || true
    echo "ERROR: 'convert' (ImageMagick) is not installed. Run: sudo pacman -S imagemagick" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") <image1> [image2] ..."
    exit 1
fi

success=0
failed=0

for src in "$@"; do

    # Skip non-files
    if [[ ! -f "$src" ]]; then
        echo "Skipping (not a file): $src"
        (( failed++ )) || true
        continue
    fi

    # Determine output path
    dir="$(dirname "$src")"
    base="$(basename "$src")"
    name="${base%.*}"                            # strip extension
    dest="${dir}/${name}${OUTPUT_SUFFIX}.webp"

    echo "▶ Converting: $src"

    # Step 1: Resize to 800 px wide (retaining aspect ratio) into a temp PNG
    tmp="$(mktemp /tmp/webp-resize-XXXXXX.png)"
    trap 'rm -f "$tmp"' EXIT

    if ! convert "$src" -resize "${TARGET_WIDTH}>" "$tmp" 2>/dev/null; then
        echo "  ✗ Resize failed for: $src"
        (( failed++ )) || true
        rm -f "$tmp"
        continue
    fi

    # Step 2: Encode to WebP
    if ! cwebp -q "$QUALITY" "$tmp" -o "$dest" 2>/dev/null; then
        echo "  ✗ WebP encoding failed for: $src"
        (( failed++ )) || true
        rm -f "$tmp"
        continue
    fi

    rm -f "$tmp"

    src_size=$(du -sh "$src" 2>/dev/null | cut -f1)
    dst_size=$(du -sh "$dest" 2>/dev/null | cut -f1)
    echo "  ✔ Saved → $dest  ($src_size → $dst_size)"
    (( success++ )) || true

done

# Summary desktop notification
msg="${success} file(s) converted successfully."
[[ $failed -gt 0 ]] && msg+=" ${failed} failed."

notify-send "convert-to-webp" "$msg" 2>/dev/null || true
echo ""
echo "Done. $msg"
