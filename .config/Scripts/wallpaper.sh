#!/usr/bin/env bash
# wallpaper.sh — wallpaper picker & applier for dwm / X11
# Uses rofi, feh, pywal, xrdb. Auto-updates ~/.xinitrc.
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────
WALLPAPER_DIR="$HOME/wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper"
CACHE_LAST="$CACHE_DIR/last"
XINITRC="$HOME/.xinitrc"

# Block markers for managed section in .xinitrc
BLOCK_START="# >>> wallpaper.sh managed >>>"
BLOCK_END="# <<< wallpaper.sh managed <<<"

# Key combo sent via xdotool to reload dwm colours (MODKEY+F5)
RELOAD_KEY="super+F5"

# Supported image extensions (case-insensitive)
IMAGE_EXTS=("png" "jpg" "jpeg" "webp" "bmp")

# ─── Dependency check ────────────────────────────────────────────────────
REQUIRED_DEPS=(rofi feh wal xrdb awk sed find)
missing=()

for dep in "${REQUIRED_DEPS[@]}"; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
done

if ((${#missing[@]})); then
    printf "ERROR: missing required dependencies: %s\n" "${missing[*]}" >&2
    exit 1
fi

HAS_XDOTOOL=false
if command -v xdotool &>/dev/null; then
    HAS_XDOTOOL=true
else
    printf "NOTE: xdotool not found — dwm colour reload will be skipped.\n" >&2
fi

# ─── Helpers ─────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  (none)              Open rofi picker to select a wallpaper
  --apply <path>      Apply the given image directly
  --restore           Re-apply the last used wallpaper
  --help              Show this help message

Wallpaper directory: $WALLPAPER_DIR
Cache file:          $CACHE_LAST
EOF
    exit 0
}

# Apply wallpaper: feh → wal → xrdb merge → optional dwm reload
apply_wallpaper() {
    local img="$1"

    if [[ ! -f "$img" ]]; then
        printf "ERROR: file not found: %s\n" "$img" >&2
        exit 1
    fi

    # Resolve to absolute path
    img="$(realpath "$img")"

    # Set wallpaper
    feh --bg-fill "$img"

    # Generate colour scheme
    wal -i "$img"

    # Merge Xresources so dwm / status2d-xrdb pick up new colours
    local xres="$HOME/.cache/wal/colors.Xresources"
    local xextra="$HOME/.cache/wal/xrdb_extra"
    local merge_files=()
    [[ -f "$xres" ]]   && merge_files+=("$xres")
    [[ -f "$xextra" ]] && merge_files+=("$xextra")

    if ((${#merge_files[@]})); then
        cat "${merge_files[@]}" | xrdb -merge
    fi

    # Reload dwm xrdb colours via xdotool (simulates MODKEY+F5)
    if $HAS_XDOTOOL; then
        xdotool key --clearmodifiers $RELOAD_KEY || true
    fi

    # Persist choice
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$img" > "$CACHE_LAST"

    # Update .xinitrc
    update_xinitrc "$img"

    printf "Wallpaper applied: %s\n" "$img"
}

# ─── .xinitrc management ────────────────────────────────────────────────
# Inserts/updates a managed block with feh + wal commands.
# If the block already exists → replace in-place.
# If bare feh --bg-fill / wal -i lines exist → replace them with the block.
# Otherwise → insert block before the `exec ...dwm` line.
update_xinitrc() {
    local img="$1"

    # Ensure .xinitrc exists
    [[ -f "$XINITRC" ]] || return 0

    # Build the new managed block
    local block
    block="$(printf '%s\n%s\n%s\n%s' \
        "$BLOCK_START" \
        "feh --bg-fill \"$img\" &" \
        "wal -i \"$img\" &" \
        "$BLOCK_END")"

    if grep -qF "$BLOCK_START" "$XINITRC"; then
        # ── Case 1: managed block already exists → replace it ──
        awk -v start="$BLOCK_START" -v end_mark="$BLOCK_END" -v new="$block" '
            $0 == start { skip=1; next }
            skip && $0 == end_mark { skip=0; print new; next }
            skip { next }
            { print }
        ' "$XINITRC" > "$XINITRC.tmp"
        mv -- "$XINITRC.tmp" "$XINITRC"
    elif grep -qE '^[[:space:]]*(feh --bg-fill|wal -i)' "$XINITRC"; then
        # ── Case 2: bare feh/wal lines exist (no block yet) ──
        # Replace the first feh --bg-fill line with the full block,
        # and delete any standalone wal -i line.
        local first_feh=true
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*feh\ --bg-fill ]] && $first_feh; then
                printf '%s\n' "$block"
                first_feh=false
            elif [[ "$line" =~ ^[[:space:]]*wal\ -i ]]; then
                # skip bare wal line (now inside the block)
                continue
            else
                printf '%s\n' "$line"
            fi
        done < "$XINITRC" > "$XINITRC.tmp"
        mv -- "$XINITRC.tmp" "$XINITRC"
    else
        # ── Case 3: nothing exists → insert before exec ...dwm ──
        awk -v block="$block" '
            /^[[:space:]]*exec[[:space:]].*dwm/ {
                print block
                print ""
            }
            { print }
        ' "$XINITRC" > "$XINITRC.tmp"
        mv -- "$XINITRC.tmp" "$XINITRC"
    fi
}

# ─── Rofi picker ─────────────────────────────────────────────────────────
pick_wallpaper() {
    if [[ ! -d "$WALLPAPER_DIR" ]]; then
        printf "ERROR: wallpaper directory not found: %s\n" "$WALLPAPER_DIR" >&2
        exit 1
    fi

    # Collect image files (basenames) — handles spaces in filenames
    local -a names=()
    while IFS= read -r -d '' f; do
        names+=("$(basename "$f")")
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
           -o -iname '*.webp' -o -iname '*.bmp' \) -print0 | sort -z)

    if ((${#names[@]} == 0)); then
        printf "ERROR: no images found in %s\n" "$WALLPAPER_DIR" >&2
        exit 1
    fi

    local choice
    choice=$(printf '%s\n' "${names[@]}" | rofi -dmenu -p "Wallpaper") || exit 0

    [[ -z "$choice" ]] && exit 0

    apply_wallpaper "$WALLPAPER_DIR/$choice"
}

# ─── Restore last wallpaper ─────────────────────────────────────────────
restore_wallpaper() {
    if [[ ! -f "$CACHE_LAST" ]]; then
        printf "ERROR: no cached wallpaper found at %s\n" "$CACHE_LAST" >&2
        exit 1
    fi

    local last
    last=$(<"$CACHE_LAST")
    apply_wallpaper "$last"
}

# ─── Main ────────────────────────────────────────────────────────────────
case "${1:-}" in
    --apply)
        [[ -z "${2:-}" ]] && { printf "ERROR: --apply requires a path\n" >&2; exit 1; }
        apply_wallpaper "$2"
        ;;
    --restore)
        restore_wallpaper
        ;;
    --help|-h)
        usage
        ;;
    "")
        pick_wallpaper
        ;;
    *)
        printf "Unknown option: %s\n" "$1" >&2
        usage
        ;;
esac
