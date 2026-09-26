# Using LumaDrift

## First launch

Open **LumaDrift** from Applications and click **Set Up LumaDrift**. Keep the
app open while it downloads and prepares your wallpaper choices. This happens
only once for each wallpaper and can take time because the output is
quality-focused.

## Choose a live wallpaper

1. Click a wallpaper card.
2. Click **Set Live Wallpaper**.

The background changes immediately and returns automatically after you sign in.
You can close the LumaDrift window without stopping the wallpaper.

## Add your own video

1. Click **Add Video…**.
2. Choose a movie that plays in QuickTime Player.
3. Select the new card.
4. Click **Set Live Wallpaper**.

LumaDrift keeps a private managed copy, so moving or disconnecting the original
does not break the wallpaper.

## Window controls

The red, yellow, and green controls close, minimize, and enlarge LumaDrift. The
window can also be moved and resized like any other Mac app.

## Battery behavior

Video uses more energy than a still wallpaper, but LumaDrift does not prevent
display sleep and does not disable macOS battery-saving features. Your normal
Mac energy settings remain in charge.

## Troubleshooting

### Setup did not finish

Check the internet connection and free storage, then press **Set Up LumaDrift**
again. Completed downloads are reused. Detailed setup information is stored in
`~/Library/Logs/LumaDriftSetup.log`.

### The background is black

Open LumaDrift, select a different prepared card, and click **Set Live
Wallpaper**. If no cards appear, run the setup again.

### A custom movie will not import

Try opening it in QuickTime Player. DRM-protected or unsupported video cannot
be imported. Converting it to HEVC or H.264 usually fixes the issue.

### Where LumaDrift stores files

- App: `/Applications/LumaDrift.app`
- Wallpaper library: `~/Library/Application Support/LumaDrift`
- Background helper: `~/Library/Application Support/LumaDrift/LumaDrift Renderer.app`
- Login helper: `~/Library/LaunchAgents/io.github.est1994apdel.lumadrift-renderer.plist`
- Setup log: `~/Library/Logs/LumaDriftSetup.log`
