# Install LumaDrift

## Normal installation

You do not need Terminal, Xcode, Homebrew, or programming knowledge.

1. Open the [latest LumaDrift release](https://github.com/est1994ap-del/LumaDrift/releases/latest).
2. Download `LumaDrift-1.0.0-macOS-arm64.pkg`.
3. Double-click the downloaded package.
4. Click **Continue**, then **Install**.
5. Open **LumaDrift** from the Applications folder.
6. Click **Set Up LumaDrift**.
7. Leave the app open while it downloads and prepares the wallpapers.
8. Select a wallpaper and click **Set Live Wallpaper**.

That is the complete setup.

## If macOS blocks the installer

This first independent build is not yet signed with an Apple Developer ID or
notarized by Apple. If macOS says it cannot verify the developer:

1. Close the warning.
2. Control-click `LumaDrift-1.0.0-macOS-arm64.pkg` in Downloads.
3. Choose **Open**.
4. Click **Open** again, then finish the installer.

This is a one-time step. The source and checksum are available with the release
for inspection and verification.

## Requirements

- Apple-silicon Mac
- macOS 14 or later
- Internet access for Apple wallpaper downloads
- Several gigabytes of free storage for source and prepared video

The first setup is quality-focused. Downloading and preparing 5K video may take
substantially longer than installing an ordinary app. Completed files are
reused; LumaDrift does not redo them on every launch.

## Update

Download the newer `.pkg` from Releases and double-click it. The installer
replaces the app while preserving your wallpaper library and selection.

## Remove

Move **LumaDrift** from Applications to the Trash. To remove the background
helper and downloaded wallpaper library as well, developers can run the
included `uninstall.sh` from a source checkout.

## Build from source

This section is only for developers. Apple's free Command Line Tools are
required.

```sh
git clone https://github.com/est1994ap-del/LumaDrift.git
cd LumaDrift
./install.sh
```

If `swiftc` is missing, run `xcode-select --install`, complete Apple's setup,
then run `./install.sh` again.
