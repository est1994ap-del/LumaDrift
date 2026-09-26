#!/bin/zsh
set -eu

project_dir="${0:A:h:h}"
version="${1:-}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./scripts/package-release.sh VERSION" >&2
  exit 1
fi

if ! git -C "$project_dir" diff --quiet || ! git -C "$project_dir" diff --cached --quiet; then
  echo "Commit or stash tracked changes before packaging." >&2
  exit 1
fi

dist_dir="$project_dir/dist"
archive="$dist_dir/LumaDrift-$version-source.zip"
mkdir -p "$dist_dir"
rm -f "$archive"

git -C "$project_dir" archive \
  --format=zip \
  --prefix="LumaDrift-$version/" \
  --output="$archive" \
  HEAD

cd "$dist_dir"
artifacts=()
[[ -f "LumaDrift-$version-source.zip" ]] && artifacts+=("LumaDrift-$version-source.zip")
[[ -f "LumaDrift-$version-macOS-arm64.pkg" ]] && artifacts+=("LumaDrift-$version-macOS-arm64.pkg")
shasum -a 256 "${artifacts[@]}" > SHA256SUMS.txt
echo "Created $archive"
echo "Created $dist_dir/SHA256SUMS.txt"
