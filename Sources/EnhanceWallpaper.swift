import Foundation
import AppKit
import AVFoundation
import CoreImage
import CoreGraphics
import CoreVideo
import Metal
import VideoToolbox

private struct Configuration {
    let input: URL
    let output: URL
    let duration: Double?

    static func parse() throws -> Configuration {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Usage: EnhanceWallpaper INPUT OUTPUT [SECONDS]"]
            )
        }

        return Configuration(
            input: URL(fileURLWithPath: arguments[1]),
            output: URL(fileURLWithPath: arguments[2]),
            duration: arguments.count >= 4 ? Double(arguments[3]) : nil
        )
    }
}

private final class WallpaperEnhancer {
    private let width: Int
    private let height: Int
    private let fps: Int32 = 60
    private let bitRate = 55_000_000
    private let context: CIContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)!

    init() throws {
        width = 5120
        let screenAspect = NSScreen.main.map { $0.frame.width / $0.frame.height } ?? (16.0 / 10.0)
        let calculatedHeight = Int((CGFloat(width) / screenAspect).rounded())
        height = calculatedHeight - (calculatedHeight % 2)

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "A Metal GPU is required"]
            )
        }

        context = CIContext(
            mtlDevice: device,
            options: [
                .workingColorSpace: colorSpace,
                .outputColorSpace: colorSpace,
                .cacheIntermediates: false,
                .highQualityDownsample: true
            ]
        )
    }

    func run(_ configuration: Configuration) throws {
        let asset = AVURLAsset(url: configuration.input)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Input has no video track"]
            )
        }

        let reader = try AVAssetReader(asset: asset)
        if let duration = configuration.duration {
            reader.timeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: duration, preferredTimescale: 600)
            )
        }

        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ]
        )
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Could not configure the video reader"]
            )
        }
        reader.add(readerOutput)

        try? FileManager.default.removeItem(at: configuration.output)
        let writer = try AVAssetWriter(outputURL: configuration.output, fileType: .mov)
        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: bitRate,
            AVVideoExpectedSourceFrameRateKey: Int(fps),
            AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
            AVVideoAllowFrameReorderingKey: true,
            AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel
        ]
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compression,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        guard writer.canAdd(writerInput) else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Could not configure the 5K HEVC writer"]
            )
        }
        writer.add(writerInput)

        guard writer.startWriting(), reader.startReading() else {
            throw writer.error ?? reader.error ?? NSError(
                domain: "EnhanceWallpaper",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Could not start transcoding"]
            )
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw NSError(
                domain: "EnhanceWallpaper",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Could not create the 10-bit pixel-buffer pool"]
            )
        }

        let totalSeconds = configuration.duration ?? CMTimeGetSeconds(asset.duration)
        let outputFrameCount = Int((totalSeconds * Double(fps)).rounded(.down))
        var frameIndex: Int64 = 0
        var nextInputTime = CMTime.zero
        let outputBounds = CGRect(x: 0, y: 0, width: width, height: height)

        while let sample = readerOutput.copyNextSampleBuffer() {
            if frameIndex >= outputFrameCount { break }

            let inputTime = CMSampleBufferGetPresentationTimeStamp(sample)
            if inputTime < nextInputTime { continue }
            guard let sourceBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }

            while !writerInput.isReadyForMoreMediaData {
                if writer.status == .failed {
                    throw writer.error ?? NSError(
                        domain: "EnhanceWallpaper",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "Writer failed"]
                    )
                }
                usleep(1_000)
            }

            var destinationBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destinationBuffer)
            guard result == kCVReturnSuccess, let destinationBuffer else {
                throw NSError(
                    domain: "EnhanceWallpaper",
                    code: 9,
                    userInfo: [NSLocalizedDescriptionKey: "Could not allocate an output frame"]
                )
            }

            autoreleasepool {
                let enhanced = enhance(CIImage(cvPixelBuffer: sourceBuffer))
                context.render(
                    enhanced,
                    to: destinationBuffer,
                    bounds: outputBounds,
                    colorSpace: colorSpace
                )
            }

            let outputTime = CMTime(value: frameIndex, timescale: fps)
            guard adaptor.append(destinationBuffer, withPresentationTime: outputTime) else {
                throw writer.error ?? NSError(
                    domain: "EnhanceWallpaper",
                    code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "Could not append an enhanced frame"]
                )
            }

            frameIndex += 1
            nextInputTime = CMTime(value: frameIndex, timescale: fps)

            if frameIndex % 60 == 0 {
                let progress = min(100, Int(Double(frameIndex) / Double(outputFrameCount) * 100))
                print("progress=\(progress)% frames=\(frameIndex)/\(outputFrameCount)")
                fflush(stdout)
            }
        }

        writerInput.markAsFinished()
        let completion = DispatchSemaphore(value: 0)
        writer.finishWriting { completion.signal() }
        completion.wait()

        guard writer.status == .completed else {
            throw writer.error ?? NSError(
                domain: "EnhanceWallpaper",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "The enhanced movie did not finish"]
            )
        }

        print("completed=\(configuration.output.path)")
    }

    private func enhance(_ source: CIImage) -> CIImage {
        let sourceExtent = source.extent
        let targetAspect = CGFloat(width) / CGFloat(height)
        let cropWidth = sourceExtent.height * targetAspect
        let cropRect = CGRect(
            x: sourceExtent.midX - cropWidth / 2,
            y: sourceExtent.minY,
            width: cropWidth,
            height: sourceExtent.height
        ).integral

        var image = source
            .clampedToExtent()
            .applyingFilter("CINoiseReduction", parameters: [
                "inputNoiseLevel": 0.012,
                "inputSharpness": 0.32
            ])
            .cropped(to: cropRect)

        let scale = CGFloat(height) / cropRect.height
        image = image
            .transformed(by: CGAffineTransform(
                translationX: -cropRect.minX,
                y: -cropRect.minY
            ))
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: scale,
                kCIInputAspectRatioKey: 1.0
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.35,
                "inputRadius": 1.0
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.035,
                kCIInputContrastKey: 1.025,
                kCIInputBrightnessKey: 0.0
            ])
            .applyingFilter("CIVibrance", parameters: [
                "inputAmount": 0.08
            ])

        return image.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}

do {
    let configuration = try Configuration.parse()
    let enhancer = try WallpaperEnhancer()
    try enhancer.run(configuration)
} catch {
    fputs("error=\(error.localizedDescription)\n", stderr)
    exit(1)
}
