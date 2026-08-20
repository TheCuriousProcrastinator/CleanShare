import CoreMedia
import ScreenCaptureKit

@MainActor
final class ScreenCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    var onFrame: ((CMSampleBuffer) -> Void)?
    var onStreamError: ((Error) -> Void)?

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "CleanShare.ScreenCaptureFrames", qos: .userInteractive)

    var isCapturing: Bool { stream != nil }

    func start(
        configuration savedConfiguration: CaptureConfiguration,
        display descriptor: DisplayDescriptor
    ) async throws {
        await stop()

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )
        guard let display = content.displays.first(where: { $0.displayID == descriptor.id }) else {
            throw CaptureError.displayUnavailable
        }

        let ownApplication = content.applications.first { application in
            application.processID == ProcessInfo.processInfo.processIdentifier
        }
        guard let ownApplication else {
            throw CaptureError.couldNotExcludeCleanShare
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [ownApplication],
            exceptingWindows: []
        )

        let sourceRect = savedConfiguration.sourceRect(for: descriptor)
        guard sourceRect.width >= 2, sourceRect.height >= 2 else {
            throw CaptureError.invalidRegion
        }

        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.sourceRect = sourceRect
        streamConfiguration.width = max(2, Int((sourceRect.width * descriptor.pixelScale).rounded()))
        streamConfiguration.height = max(2, Int((sourceRect.height * descriptor.pixelScale).rounded()))
        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        streamConfiguration.queueDepth = 5
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.showsCursor = true
        streamConfiguration.capturesAudio = false
        streamConfiguration.scalesToFit = true
        streamConfiguration.preservesAspectRatio = true

        let newStream = SCStream(filter: filter, configuration: streamConfiguration, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await newStream.startCapture()
        stream = newStream
    }

    func stop() async {
        guard let activeStream = stream else { return }
        stream = nil
        try? await activeStream.stopCapture()
        try? activeStream.removeStreamOutput(self, type: .screen)
    }

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen, sampleBuffer.isValid else { return }
        let transferredBuffer = SendableSampleBuffer(sampleBuffer)
        Task { @MainActor [weak self] in
            self?.onFrame?(transferredBuffer.value)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.stream = nil
            self?.onStreamError?(error)
        }
    }
}

/// ScreenCaptureKit owns immutable frame buffers and explicitly delivers them on
/// a client-selected queue. Retaining one while hopping to the UI actor is safe.
private final class SendableSampleBuffer: @unchecked Sendable {
    nonisolated(unsafe) let value: CMSampleBuffer

    nonisolated init(_ value: CMSampleBuffer) {
        self.value = value
    }
}

enum CaptureError: LocalizedError {
    case displayUnavailable
    case invalidRegion
    case couldNotExcludeCleanShare

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            "The saved display is no longer connected. Choose a new capture area."
        case .invalidRegion:
            "The saved capture area is too small. Choose a new capture area."
        case .couldNotExcludeCleanShare:
            "CleanShare could not safely exclude its own windows from capture."
        }
    }
}
