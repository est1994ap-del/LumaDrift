import Foundation

private struct Manifest: Decodable {
    let assets: [Asset]
}

private struct Asset: Decodable {
    let id: String
    let categories: [String]?
    let variant: Variant?
    let url: String?

    private enum CodingKeys: String, CodingKey {
        case id, categories, variant
        case url = "url-4K-SDR-240FPS"
    }
}

private struct Variant: Decodable {
    let orientation: String
    let appearance: String
}

private struct CatalogEntry: Codable {
    let id: String
    let name: String
    let subtitle: String
    let videoPath: String
    let thumbnailPath: String
}

private func fail(_ message: String) -> Never {
    fputs("CatalogTool: \(message)\n", stderr)
    exit(1)
}

private let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail("missing command")
}

do {
    switch command {
    case "apple-assets":
        guard arguments.count == 2 else { fail("usage: CatalogTool apple-assets MANIFEST") }
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        for asset in manifest.assets {
            guard
                let variant = asset.variant,
                variant.orientation == "landscape",
                asset.categories?.contains("dynamic-aerials") == true,
                let url = asset.url
            else { continue }
            print("\(asset.id)\t\(variant.appearance)\t\(url)")
        }

    case "record":
        guard arguments.count == 6 else {
            fail("usage: CatalogTool record ID NAME SUBTITLE VIDEO_PATH THUMBNAIL_PATH")
        }
        let entry = CatalogEntry(
            id: arguments[1],
            name: arguments[2],
            subtitle: arguments[3],
            videoPath: arguments[4],
            thumbnailPath: arguments[5]
        )
        let data = try JSONEncoder().encode(entry)
        guard let line = String(data: data, encoding: .utf8) else { fail("could not encode record") }
        print(line)

    case "array":
        guard arguments.count == 3 else { fail("usage: CatalogTool array NDJSON OUTPUT") }
        let source = try String(contentsOfFile: arguments[1], encoding: .utf8)
        let decoder = JSONDecoder()
        let entries = try source.split(whereSeparator: \Character.isNewline).map {
            try decoder.decode(CatalogEntry.self, from: Data($0.utf8))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(
            to: URL(fileURLWithPath: arguments[2]),
            options: .atomic
        )

    default:
        fail("unknown command: \(command)")
    }
} catch {
    fail(error.localizedDescription)
}
