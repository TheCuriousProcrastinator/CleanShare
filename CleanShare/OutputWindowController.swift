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

    func updatePresentation(isPaused: Bool, isBlackScreen: Bool) {
        displayView.updatePresentation(isPaused: isPaused, isBlackScreen: isBlackScreen)
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
    private let containerLayer = CALayer()
    private let displayLayer = AVSampleBufferDisplayLayer()
    private let blackScreenLayer = CALayer()
    private var isPaused = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = containerLayer
        containerLayer.backgroundColor = NSColor.black.cgColor
        containerLayer.addSublayer(displayLayer)
        containerLayer.addSublayer(blackScreenLayer)
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.black.cgColor
        blackScreenLayer.backgroundColor = NSColor.black.cgColor
        blackScreenLayer.isHidden = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        blackScreenLayer.frame = bounds
        CATransaction.commit()
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard !isPaused else { return }
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed {
            renderer.flush()
        }
        guard renderer.isReadyForMoreMediaData else { return }
        renderer.enqueue(sampleBuffer)
    }

    func updatePresentation(isPaused: Bool, isBlackScreen: Bool) {
        self.isPaused = isPaused
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blackScreenLayer.isHidden = !isBlackScreen
        CATransaction.commit()
    }

    func reset() {
        isPaused = false
        blackScreenLayer.isHidden = true
        displayLayer.sampleBufferRenderer.flush(
            removingDisplayedImage: true,
            completionHandler: nil
        )
    }
}
