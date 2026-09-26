import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
private let supportDirectory = homeDirectory + "/Library/Application Support/LumaDrift"
private let catalogPath = supportDirectory + "/Catalog.json"
private let selectionPath = supportDirectory + "/CurrentVideoPath.txt"
private let importedDirectory = supportDirectory + "/Imported"
private let importedThumbnailDirectory = supportDirectory + "/Imported Thumbnails"
private let selectionChangedNotification = Notification.Name("io.github.est1994apdel.LumaDrift.selectionChanged")

private struct WallpaperOption: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let videoPath: String
    let thumbnailPath: String

    var isPrepared: Bool {
        FileManager.default.fileExists(atPath: videoPath)
    }
}

@MainActor
private final class WallpaperModel: ObservableObject {
    @Published var options: [WallpaperOption] = []
    @Published var selectedID: String?
    @Published var statusMessage = "Choose a wallpaper"
    @Published var isPreparing = false

    init() {
        load()
    }

    var selectedOption: WallpaperOption? {
        options.first(where: { $0.id == selectedID })
    }

    func load() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: catalogPath))
            options = try JSONDecoder().decode([WallpaperOption].self, from: data)

            let selectedPath = (try? String(contentsOfFile: selectionPath, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            selectedID = options.first(where: { $0.videoPath == selectedPath })?.id
                ?? options.first(where: { $0.isPrepared })?.id
            statusMessage = options.isEmpty ? "No prepared wallpapers found" : "Ready"
        } catch {
            options = []
            statusMessage = "Wallpaper catalog is unavailable"
        }
    }

    func applySelection() {
        guard let option = selectedOption, option.isPrepared else {
            statusMessage = "This wallpaper has not been prepared yet"
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: supportDirectory),
                withIntermediateDirectories: true
            )
            try (option.videoPath + "\n").write(
                toFile: selectionPath,
                atomically: true,
                encoding: .utf8
            )
            DistributedNotificationCenter.default().postNotificationName(
                selectionChangedNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            statusMessage = "\(option.name) is now live"
        } catch {
            statusMessage = "Could not change the wallpaper"
        }
    }

    func prepareLibrary() {
        guard !isPreparing else { return }
        guard let setupURL = Bundle.main.url(forResource: "Setup", withExtension: "command") else {
            statusMessage = "Setup files are missing. Download LumaDrift again."
            return
        }

        isPreparing = true
        statusMessage = "Preparing your live wallpapers…"

        DispatchQueue.global(qos: .userInitiated).async {
            let succeeded = Self.runSetup(at: setupURL)
            DispatchQueue.main.async {
                self.isPreparing = false
                self.load()
                if !succeeded {
                    self.statusMessage = "Setup could not finish. Check your connection and try again."
                }
            }
        }
    }

    nonisolated private static func runSetup(at setupURL: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [setupURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func addVideo() {
        let panel = NSOpenPanel()
        panel.title = "Add a Live Wallpaper Video"
        panel.message = "Choose a video to copy into your live wallpaper library."
        panel.prompt = "Add Video"
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: importedDirectory),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: importedThumbnailDirectory),
                withIntermediateDirectories: true
            )

            let id = UUID().uuidString
            let destinationURL = URL(fileURLWithPath: importedDirectory)
                .appendingPathComponent("\(id)-\(sourceURL.lastPathComponent)")
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            let thumbnailURL = URL(fileURLWithPath: importedThumbnailDirectory)
                .appendingPathComponent("\(id).png")
            try createThumbnail(for: destinationURL, at: thumbnailURL)

            let displayName = sourceURL.deletingPathExtension().lastPathComponent
            let option = WallpaperOption(
                id: id,
                name: displayName,
                subtitle: "Imported Video · Original quality",
                videoPath: destinationURL.path,
                thumbnailPath: thumbnailURL.path
            )
            options.append(option)
            selectedID = id
            try saveCatalog()
            statusMessage = "\(displayName) was added"
        } catch {
            statusMessage = "Could not add that video"
        }
    }

    private func saveCatalog() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(options)
        try data.write(to: URL(fileURLWithPath: catalogPath), options: .atomic)
    }

    private func createThumbnail(for videoURL: URL, at thumbnailURL: URL) throws {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 800)
        let image = try generator.copyCGImage(
            at: CMTime(seconds: 1, preferredTimescale: 600),
            actualTime: nil
        )
        let representation = NSBitmapImageRep(cgImage: image)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "LumaDrift",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create a thumbnail"]
            )
        }
        try png.write(to: thumbnailURL, options: .atomic)
    }
}

private struct WallpaperCard: View {
    let option: WallpaperOption
    let isSelected: Bool
    let action: () -> Void

    private var thumbnail: NSImage? {
        NSImage(contentsOfFile: option.thumbnailPath)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.blue.opacity(0.75), .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                Image(systemName: "sparkles.tv")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .frame(height: 148)
                    .clipped()

                    if isSelected {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(.blue, in: Capsule())
                            .padding(10)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Image(systemName: option.isPrepared ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(option.isPrepared ? .green : .secondary)
                        Text(option.subtitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                .padding(13)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 3 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name), \(option.subtitle)")
    }
}

private struct WindowControl: View {
    let color: Color
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.black.opacity(0.58))
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct ContentView: View {
    @StateObject private var model = WallpaperModel()

    private let columns = [
        GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 18)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                HStack(spacing: 6) {
                    WindowControl(color: Color(red: 1.0, green: 0.37, blue: 0.34), symbol: "xmark", label: "Close") {
                        NSApp.keyWindow?.performClose(nil)
                    }
                    WindowControl(color: Color(red: 1.0, green: 0.74, blue: 0.18), symbol: "minus", label: "Minimize") {
                        NSApp.keyWindow?.miniaturize(nil)
                    }
                    WindowControl(color: Color(red: 0.16, green: 0.78, blue: 0.31), symbol: "arrow.up.left.and.arrow.down.right", label: "Expand") {
                        NSApp.keyWindow?.zoom(nil)
                    }
                }

                Divider()
                    .frame(height: 30)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .shadow(color: .blue.opacity(0.25), radius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LumaDrift")
                        .font(.title2.weight(.semibold))
                    Text("Apple motion wallpapers, enhanced for this display")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            if model.options.isEmpty {
                VStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 104, height: 104)
                        .shadow(color: .blue.opacity(0.3), radius: 24)
                    Text("Bring your desktop to life")
                        .font(.title.weight(.semibold))
                    Text("LumaDrift prepares Apple's motion wallpapers automatically.\nThis one-time setup may take a while for maximum quality.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    if model.isPreparing {
                        ProgressView()
                            .controlSize(.large)
                        Text(model.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Set Up LumaDrift") {
                            model.prepareLibrary()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(model.options) { option in
                            WallpaperCard(
                                option: option,
                                isSelected: model.selectedID == option.id,
                                action: { model.selectedID = option.id }
                            )
                        }
                    }
                    .padding(24)
                }
            }

            Divider()

            if !model.options.isEmpty {
                HStack(spacing: 12) {
                    Label("Starts automatically at login", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)

                    Spacer()

                    Button("Add Video…", systemImage: "plus") {
                        model.addVideo()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Text(model.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Set Live Wallpaper") {
                        model.applySelection()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.selectedOption?.isPrepared != true)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LumaDrift"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 860, height: 560)
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        window.setFrameAutosaveName("LumaDrift.MainWindow")
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
