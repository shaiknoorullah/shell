#!/usr/bin/env bash
#
# rofi-wallpaper.sh — Two-step wallpaper browser
#
# Step 1: Category grid with preview thumbnails
# Step 2: Horizontal wallpaper slider with live preview (rofi-blocks)

ROFI_DIR="$HOME/.config/rofi"
THEME_DIR="$ROFI_DIR/themes"
WALL_DIR="$HOME/walls"
CACHE_DIR="$HOME/.cache/rofi-wallpaper"

if [[ ! -d "$WALL_DIR" ]]; then
    notify-send "Error" "Wallpapers directory not found: $WALL_DIR" -u critical
    exit 1
fi

mkdir -p "$CACHE_DIR/thumbs"

# Generate category thumbnails (random image from each folder)
generate_category_thumbs() {
    for dir in "$WALL_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        cat_name=$(basename "$dir")
        thumb="$CACHE_DIR/thumbs/$cat_name.png"
        # Only regenerate if missing or older than 1 hour
        if [[ ! -f "$thumb" ]] || [[ $(find "$thumb" -mmin +60 2>/dev/null) ]]; then
            # Pick a random image from the category
            img=$(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n1)
            if [[ -n "$img" ]]; then
                convert "$img" -resize 400x225^ -gravity center -extent 400x225 "$thumb" 2>/dev/null
            fi
        fi
    done
}

generate_category_thumbs

# Build category entries with preview icons
entries=""
for dir in "$WALL_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    cat_name=$(basename "$dir")
    count=$(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | wc -l)
    thumb="$CACHE_DIR/thumbs/$cat_name.png"
    if [[ -f "$thumb" ]]; then
        entries+="$cat_name ($count)\x00icon\x1f$thumb\n"
    else
        entries+="$cat_name ($count)\n"
    fi
done

# Step 1: Category selector (6-column grid)
r_override="window{width:80%;}
    listview{columns:4;lines:2;}
    element{orientation:vertical;border-radius:16px;padding:1em;}
    element-icon{border-radius:12px;size:14em;}
    element-text{horizontal-align:0.5;}"

chosen_cat=$(echo -en "$entries" | rofi -dmenu \
    -theme "$THEME_DIR/selector" \
    -theme-str 'configuration {show-icons: true;}' \
    -theme-str "$r_override" \
    -show-icons \
    -p "Category" \
    -mesg "Select a wallpaper category")

if [[ -z "$chosen_cat" ]]; then
    exit 0
fi

# Strip the count suffix: "dark-minimal (15)" -> "dark-minimal"
chosen_cat=$(echo "$chosen_cat" | sed 's/ ([0-9]*)$//')

# Step 2: Launch the wallpaper slider for the selected category
exec "$ROFI_DIR/scripts/rofi-wallpaper-slider.sh" "$chosen_cat"
