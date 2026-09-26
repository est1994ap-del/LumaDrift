import AppKit
import AVFoundation
import CoreGraphics

private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
private let supportDirectory = homeDirectory + "/Library/Application Support/LumaDrift"
private let selectionPath = supportDirectory + "/CurrentVideoPath.txt"
private let fallbackVideoPath = supportDirectory + "/Enhanced/Golden Gate Sunset 5K Enhanced.mov"
private let selectionChangedNotification = Notification.Name("io.github.est1994apdel.LumaDrift.selectionChanged")

private func selectedVideoPath() -> String {
    guard
        let value = try? String(contentsOfFile: selectionPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        FileManager.default.fileExists(atPath: value)
    else {
        return fallbackVideoPath
    }
    return value
}

private final class WallpaperSurface {
    let window: NSWindow
    let player: AVQueuePlayer
    private let looper: AVPlayerLooper
    private let playerLayer: AVPlayerLayer

    init(screen: NSScreen, videoURL: URL) {
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // One level above the static wallpaper, still below Finder's icons.
        let desktopLevel = CGWindowLevelForKey(.desktopWindow)
        window.level = NSWindow.Level(rawValue: Int(desktopLevel) + 1)
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.canHide = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        window.contentView = contentView

        player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
        // Respect macOS's display-sleep settings, especially while on battery.
        player.preventsDisplaySleepDuringVideoPlayback = false

        let item = AVPlayerItem(url: videoURL)
        looper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = contentView.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        playerLayer.videoGravity = .resizeAspectFill
        contentView.layer?.addSublayer(playerLayer)

        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        player.play()
    }

    func resume() {
        window.orderFrontRegardless()
        player.play()
    }

    func stop() {
        player.pause()
        window.orderOut(nil)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var surfaces: [WallpaperSurface] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard FileManager.default.fileExists(atPath: selectedVideoPath()) else {
            fputs("No prepared live wallpaper was found.\n", stderr)
            NSApp.terminate(nil)
            return
        }

        rebuildSurfaces()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectionChanged),
            name: selectionChangedNotification,
            object: nil
        )
    }

    @objc private func screenConfigurationChanged() {
        rebuildSurfaces()
    }

    @objc private func systemDidWake() {
        surfaces.forEach { $0.resume() }
    }

    @objc private func selectionChanged() {
        rebuildSurfaces()
    }

    private func rebuildSurfaces() {
        surfaces.forEach { $0.stop() }
        surfaces.removeAll()

        let url = URL(fileURLWithPath: selectedVideoPath())
        surfaces = NSScreen.screens.map { WallpaperSurface(screen: $0, videoURL: url) }
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
