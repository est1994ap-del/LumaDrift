#!/bin/zsh
set -eu

user_id="$(id -u)"
launch_agent="$HOME/Library/LaunchAgents/io.github.est1994apdel.lumadrift-renderer.plist"
installed_app="$HOME/Applications/LumaDrift.app"
support_dir="$HOME/Library/Application Support/LumaDrift"
desktop_shortcut="$HOME/Desktop/LumaDrift.app"

launchctl bootout "gui/$user_id/io.github.est1994apdel.lumadrift-renderer" 2>/dev/null || true
launchctl bootout "gui/$user_id/io.github.est1994apdel.aerial-live-wallpaper-renderer" 2>/dev/null || true
launchctl bootout "gui/$user_id/local.codex.aerial-live-wallpaper-renderer" 2>/dev/null || true

rm -f "$launch_agent"
rm -f "$HOME/Library/LaunchAgents/local.codex.aerial-live-wallpaper-renderer.plist"
rm -f "$HOME/Library/LaunchAgents/io.github.est1994apdel.aerial-live-wallpaper-renderer.plist"
rm -f "$desktop_shortcut"
rm -rf "$installed_app"
rm -rf "$support_dir"

echo "Removed LumaDrift and its managed media library."
