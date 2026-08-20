import AppKit
import AVFoundation
import CoreMedia

@MainActor
final class OutputWindowController: NSObject, NSWindowDelegate {
    var onUserClose: (() -> Void)?

    private let displayView = SampleBufferDisplayView()
    private var outputWindow: NSWindow?
    private var isClosingProgrammatically = false

    func show(aspectRatio: CGFloat) {
        let window = outputWindow ?? makeWindow()
        let width: CGFloat = 960
        let height = max(360, min(720, width / max(aspectRatio, 0.1)))
        window.setContentSize(CGSize(width: width, height: height))
        window.center()
        window.makeKeyAndOrderFront(nil)
        outputWindow = window
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        displayView.enqueue(sampleBuffer)
    }

    func close() {
        guard let outputWindow else { return }
        isClosingProgrammatically = true
        outputWindow.close()
        isClosingProgrammatically = false
        self.outputWindow = nil
        displayView.reset()
    }

    func windowWillClose(_ notification: Notification) {
        outputWindow = nil
        displayView.reset()
        if !isClosingProgrammatically {
            onUserClose?()
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 960, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CleanShare Output"
        window.contentMinSize = CGSize(width: 320, height: 180)
        window.backgroundColor = .black
        window.contentView = displayView
        window.delegate = self
        window.isReleasedWhenClosed = false
        return window
    }
}

private final class SampleBufferDisplayView: NSView {
    private let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = displayLayer
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed {
            renderer.flush()
        }
        guard renderer.isReadyForMoreMediaData else { return }
        renderer.enqueue(sampleBuffer)
    }

    func reset() {
        displayLayer.sampleBufferRenderer.flush(
            removingDisplayedImage: true,
            completionHandler: nil
        )
    }
}
