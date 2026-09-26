#!/bin/zsh
set -eu

project_dir="${0:A:h:h}"
version="${1:-1.0.0}"
app_bundle="$project_dir/build/LumaDrift.app"
dist_dir="$project_dir/dist"
package="$dist_dir/LumaDrift-$version-macOS-arm64.pkg"

if [ ! -d "$app_bundle" ]; then
  echo "Build LumaDrift first with ./install.sh" >&2
  exit 1
fi

mkdir -p "$dist_dir"
rm -f "$package"
pkgbuild \
  --component "$app_bundle" \
  --install-location /Applications \
  --identifier io.github.est1994apdel.LumaDrift.pkg \
  --version "$version" \
  "$package"

cd "$dist_dir"
artifacts=()
[[ -f "LumaDrift-$version-source.zip" ]] && artifacts+=("LumaDrift-$version-source.zip")
[[ -f "LumaDrift-$version-macOS-arm64.pkg" ]] && artifacts+=("LumaDrift-$version-macOS-arm64.pkg")
shasum -a 256 "${artifacts[@]}" > SHA256SUMS.txt

echo "Created $package"
echo "Updated $dist_dir/SHA256SUMS.txt"
