# Release checklist

1. Update the version in both app property lists, `CHANGELOG.md`, and `RELEASE_NOTES.md`.
2. Run `zsh ./scripts/check.sh` on a clean checkout.
3. Run `zsh ./install.sh` and verify selection, custom import, login startup, sleep, wake, and multiple displays.
4. Build the installer with `zsh ./scripts/build-installer.sh VERSION`.
5. Expand the package with `pkgutil --expand-full` and inspect its app payload.
6. Confirm no Apple video, local catalog data, logs, or user media appear in Git or the package.
7. Commit the release and create the matching `vVERSION` tag.
8. Build the source archive with `zsh ./scripts/package-release.sh VERSION`.
9. Verify `SHA256SUMS.txt` covers the source ZIP and macOS package.
10. Create the GitHub release and upload the `.pkg`, source ZIP, and checksum file.
11. Verify the public screenshot, download links, checksum, and beginner installation instructions.

## Signing and notarization

For a no-warning public installation, sign the app and package with an Apple
Developer ID and submit the package to Apple's notarization service before
uploading it. Ad-hoc signing is useful for local integrity checks but does not
replace Developer ID signing or notarization.

If an unsigned development package is published, label it clearly and include
the one-time Control-click → **Open** instruction. Never claim that an unsigned
package is notarized.

Apple media must never be attached to a release. Release artifacts contain only
the app, its local preparation tools, project source, and checksums.
