#!/bin/zsh
set -eu

project_dir="${0:A:h}"
build_dir="$project_dir/build"
app_bundle="$build_dir/LumaDrift.app"
renderer_bundle="$build_dir/LumaDrift Renderer.app"
support_dir="$HOME/Library/Application Support/LumaDrift"
legacy_support_dir="$HOME/Library/Application Support/Aerial Live Wallpapers"
source_dir="$support_dir/Sources"
enhanced_dir="$support_dir/Enhanced"
manifest="$HOME/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json"
thumbnail_dir="$HOME/Library/Application Support/com.apple.wallpaper/aerials/thumbnails"
catalog="$support_dir/Catalog.json"
selection="$support_dir/CurrentVideoPath.txt"
installed_app="$HOME/Applications/LumaDrift.app"
installed_renderer="$support_dir/LumaDrift Renderer.app"
launch_agent="$HOME/Library/LaunchAgents/io.github.est1994apdel.lumadrift-renderer.plist"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required. Run: xcode-select --install"
  exit 1
fi

if [ ! -f "$manifest" ]; then
  echo "The Apple motion-wallpaper manifest was not found on this Mac."
  exit 1
fi

if [ ! -e "$support_dir" ] && [ -d "$legacy_support_dir" ]; then
  mv "$legacy_support_dir" "$support_dir"
fi

mkdir -p \
  "$app_bundle/Contents/MacOS" \
  "$app_bundle/Contents/Resources" \
  "$renderer_bundle/Contents/MacOS" \
  "$support_dir" "$source_dir" "$enhanced_dir" \
  "$HOME/Applications" "$HOME/Library/LaunchAgents"

cp "$project_dir/App-Info.plist" "$app_bundle/Contents/Info.plist"
cp "$project_dir/Renderer-Info.plist" "$renderer_bundle/Contents/Info.plist"

swiftc -O -framework AppKit -framework AVFoundation -framework SwiftUI -framework Combine -framework UniformTypeIdentifiers \
  "$project_dir/Sources/LumaDrift.swift" \
  -o "$app_bundle/Contents/MacOS/LumaDrift"

swiftc -O -framework AppKit -framework AVFoundation -framework CoreGraphics \
  "$project_dir/Sources/LumaDriftRenderer.swift" \
  -o "$renderer_bundle/Contents/MacOS/LumaDriftRenderer"

swiftc -O \
  -framework AppKit -framework AVFoundation -framework CoreImage \
  -framework CoreGraphics -framework CoreVideo -framework Metal -framework VideoToolbox \
  "$project_dir/Sources/EnhanceWallpaper.swift" \
  -o "$build_dir/EnhanceWallpaper"

cp "$project_dir/Assets/LumaDriftIcon.png" "$build_dir/AppIcon-1024.png"

swiftc -O "$project_dir/Sources/CatalogTool.swift" -o "$build_dir/CatalogTool"

iconset="$build_dir/AppIcon.iconset"
mkdir -p "$iconset"
make_icon() { sips -z "$1" "$1" "$build_dir/AppIcon-1024.png" --out "$iconset/$2" >/dev/null; }
make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil -c icns "$iconset" -o "$app_bundle/Contents/Resources/AppIcon.icns"

mkdir -p "$app_bundle/Contents/Resources/Tools"
cp "$project_dir/Resources/Setup.command" "$app_bundle/Contents/Resources/Setup.command"
chmod +x "$app_bundle/Contents/Resources/Setup.command"
cp "$build_dir/EnhanceWallpaper" "$app_bundle/Contents/Resources/Tools/EnhanceWallpaper"
cp "$build_dir/CatalogTool" "$app_bundle/Contents/Resources/Tools/CatalogTool"
cp "$project_dir/io.github.est1994apdel.lumadrift-renderer.plist" \
  "$app_bundle/Contents/Resources/io.github.est1994apdel.lumadrift-renderer.plist"
ditto "$renderer_bundle" "$app_bundle/Contents/Resources/LumaDrift Renderer.app"

catalog_lines="$build_dir/catalog.ndjson"
: > "$catalog_lines"

legacy_golden="$HOME/Library/Application Support/Golden Gate Live Wallpaper/Golden Gate Sunset 5K Enhanced.mov"
golden_target="$enhanced_dir/Golden Gate Sunset 5K Enhanced.mov"
golden_thumbnail="$thumbnail_dir/4207734D-74FE-4F92-B5E1-6EC8DEE24A15.png"
if [ -f "$legacy_golden" ]; then
  ditto "$legacy_golden" "$golden_target"
fi
if [ -f "$golden_target" ]; then
  "$build_dir/CatalogTool" record \
    "golden-gate-sunset" \
    "Golden Gate Sunset" \
    "Landscape · 5K · 10-bit" \
    "$golden_target" \
    "$golden_thumbnail" \
    >> "$catalog_lines"
fi

"$build_dir/CatalogTool" apple-assets "$manifest" |
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
    "$build_dir/EnhanceWallpaper" "$source_movie" "$enhanced_movie"
  fi

  "$build_dir/CatalogTool" record \
    "$asset_id" \
    "macOS Dynamic — $display_appearance" \
    "Apple Dynamic · 5K · 10-bit" \
    "$enhanced_movie" \
    "$thumbnail" \
    >> "$catalog_lines"
done

"$build_dir/CatalogTool" array "$catalog_lines" "$catalog"
selected_path="$(head -n 1 "$selection" 2>/dev/null || true)"
if [ -z "$selected_path" ] || [ ! -f "$selected_path" ]; then
  /usr/bin/plutil -extract 0.videoPath raw -o - "$catalog" > "$selection"
fi

xattr -cr "$app_bundle" "$renderer_bundle"
codesign --force --deep --sign - "$app_bundle"
codesign --force --deep --sign - "$renderer_bundle"
ditto "$app_bundle" "$installed_app"
ditto "$renderer_bundle" "$installed_renderer"

sed "s|__HOME__|$HOME|g" \
  "$project_dir/io.github.est1994apdel.lumadrift-renderer.plist" \
  > "$launch_agent"

uid_value="$(id -u)"
launchctl bootout "gui/$uid_value/local.codex.golden-gate-live-wallpaper" 2>/dev/null || true
launchctl bootout "gui/$uid_value/local.codex.aerial-live-wallpaper-renderer" 2>/dev/null || true
launchctl bootout "gui/$uid_value/io.github.est1994apdel.aerial-live-wallpaper-renderer" 2>/dev/null || true
launchctl bootout "gui/$uid_value/io.github.est1994apdel.lumadrift-renderer" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/local.codex.aerial-live-wallpaper-renderer.plist"
rm -f "$HOME/Library/LaunchAgents/io.github.est1994apdel.aerial-live-wallpaper-renderer.plist"
launchctl bootstrap "gui/$uid_value" "$launch_agent"
launchctl enable "gui/$uid_value/io.github.est1994apdel.lumadrift-renderer"
launchctl kickstart -k "gui/$uid_value/io.github.est1994apdel.lumadrift-renderer"

ln -sfn "$installed_app" "$HOME/Desktop/LumaDrift.app"

echo "Installed LumaDrift."
