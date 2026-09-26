#!/bin/zsh
set -eu

project_dir="${0:A:h:h}"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

zsh -n "$project_dir/install.sh" "$project_dir/uninstall.sh" \
  "$project_dir/Resources/Setup.command" "$project_dir/scripts/package-release.sh" \
  "$project_dir/scripts/build-installer.sh"
plutil -lint "$project_dir/App-Info.plist" "$project_dir/Renderer-Info.plist" \
  "$project_dir/io.github.est1994apdel.lumadrift-renderer.plist"

swiftc -framework AppKit -framework AVFoundation -framework SwiftUI -framework Combine -framework UniformTypeIdentifiers \
  "$project_dir/Sources/LumaDrift.swift" -o "$temporary_dir/LumaDrift"
swiftc -framework AppKit -framework AVFoundation -framework CoreGraphics \
  "$project_dir/Sources/LumaDriftRenderer.swift" -o "$temporary_dir/LumaDriftRenderer"
swiftc -framework AppKit -framework AVFoundation -framework CoreImage -framework CoreGraphics \
  -framework CoreVideo -framework Metal -framework VideoToolbox \
  "$project_dir/Sources/EnhanceWallpaper.swift" -o "$temporary_dir/EnhanceWallpaper"
swiftc "$project_dir/Sources/CatalogTool.swift" -o "$temporary_dir/CatalogTool"

if find "$project_dir" -path "$project_dir/.git" -prune -o -path "$project_dir/build" -prune -o -type f -name '*.mov' -print | grep -q .; then
  echo "Movie files must not be committed to the source repository." >&2
  exit 1
fi

echo "All source checks passed."
