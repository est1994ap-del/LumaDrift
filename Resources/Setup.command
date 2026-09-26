#!/bin/zsh
set -eu

resource_dir="${0:A:h}"
tools_dir="$resource_dir/Tools"
support_dir="$HOME/Library/Application Support/LumaDrift"
source_dir="$support_dir/Sources"
enhanced_dir="$support_dir/Enhanced"
manifest="$HOME/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json"
thumbnail_dir="$HOME/Library/Application Support/com.apple.wallpaper/aerials/thumbnails"
catalog="$support_dir/Catalog.json"
selection="$support_dir/CurrentVideoPath.txt"
renderer_source="$resource_dir/LumaDrift Renderer.app"
renderer_target="$support_dir/LumaDrift Renderer.app"
launch_agent="$HOME/Library/LaunchAgents/io.github.est1994apdel.lumadrift-renderer.plist"
log_file="$HOME/Library/Logs/LumaDriftSetup.log"

mkdir -p "$support_dir" "$source_dir" "$enhanced_dir" "$HOME/Library/LaunchAgents"
exec >> "$log_file" 2>&1

if [ ! -f "$manifest" ]; then
  echo "The Apple motion-wallpaper catalog was not found."
  exit 1
fi

catalog_lines="$support_dir/catalog.ndjson"
: > "$catalog_lines"

legacy_golden="$HOME/Library/Application Support/Golden Gate Live Wallpaper/Golden Gate Sunset 5K Enhanced.mov"
golden_target="$enhanced_dir/Golden Gate Sunset 5K Enhanced.mov"
golden_thumbnail="$thumbnail_dir/4207734D-74FE-4F92-B5E1-6EC8DEE24A15.png"
if [ -f "$legacy_golden" ] && [ ! -f "$golden_target" ]; then
  ditto "$legacy_golden" "$golden_target"
fi
if [ -f "$golden_target" ]; then
  "$tools_dir/CatalogTool" record \
    "golden-gate-sunset" "Golden Gate Sunset" "Landscape · 5K · 10-bit" \
    "$golden_target" "$golden_thumbnail" >> "$catalog_lines"
fi

"$tools_dir/CatalogTool" apple-assets "$manifest" |
while IFS=$'\t' read -r asset_id appearance asset_url; do
  source_movie="$source_dir/$asset_id.mov"
  display_appearance="${(C)appearance}"
  enhanced_movie="$enhanced_dir/macOS $display_appearance 5K Enhanced.mov"
  thumbnail="$thumbnail_dir/$asset_id.png"

  if [ ! -f "$source_movie" ]; then
    echo "Downloading macOS Dynamic — $display_appearance"
    curl -L --fail --retry 3 --continue-at - --output "$source_movie" "$asset_url"
  fi
  if [ ! -f "$enhanced_movie" ]; then
    echo "Enhancing macOS Dynamic — $display_appearance"
    "$tools_dir/EnhanceWallpaper" "$source_movie" "$enhanced_movie"
  fi

  "$tools_dir/CatalogTool" record \
    "$asset_id" "macOS Dynamic — $display_appearance" "Apple Dynamic · 5K · 10-bit" \
    "$enhanced_movie" "$thumbnail" >> "$catalog_lines"
done

"$tools_dir/CatalogTool" array "$catalog_lines" "$catalog"
selected_path="$(head -n 1 "$selection" 2>/dev/null || true)"
if [ -z "$selected_path" ] || [ ! -f "$selected_path" ]; then
  /usr/bin/plutil -extract 0.videoPath raw -o - "$catalog" > "$selection"
fi

ditto "$renderer_source" "$renderer_target"
sed "s|__HOME__|$HOME|g" "$resource_dir/io.github.est1994apdel.lumadrift-renderer.plist" > "$launch_agent"

user_id="$(id -u)"
launchctl bootout "gui/$user_id/io.github.est1994apdel.lumadrift-renderer" 2>/dev/null || true
launchctl bootstrap "gui/$user_id" "$launch_agent"
launchctl enable "gui/$user_id/io.github.est1994apdel.lumadrift-renderer"
launchctl kickstart -k "gui/$user_id/io.github.est1994apdel.lumadrift-renderer"

echo "LumaDrift setup completed."
