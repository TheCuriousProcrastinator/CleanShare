import AppKit

@MainActor
final class RegionSelectionController {
    private var overlayWindow: NSWindow?

    func begin(
        on screen: NSScreen,
        completion: @escaping (CGRect?) -> Void
    ) {
        cancel()

        let selectionView = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        let window = SelectionWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = selectionView
        window.setFrame(screen.frame, display: true)

        selectionView.onFinish = { [weak self, weak window] rect in
            window?.orderOut(nil)
            self?.overlayWindow = nil
            completion(rect)
        }

        overlayWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(selectionView)
    }

    func cancel() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class RegionSelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?

    private var dragStart: CGPoint?
    private var selectionRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(dragStart.x, current.x),
            y: min(dragStart.y, current.y),
            width: abs(current.x - dragStart.x),
            height: abs(current.y - dragStart.y)
        ).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStart != nil else { return }
        mouseDragged(with: event)
        dragStart = nil

        guard selectionRect.width >= 8, selectionRect.height >= 8 else {
            onFinish?(nil)
            return
        }

        // ScreenCaptureKit uses a top-left origin. AppKit views use bottom-left.
        let normalizedRect = CGRect(
            x: selectionRect.minX / bounds.width,
            y: (bounds.height - selectionRect.maxY) / bounds.height,
            width: selectionRect.width / bounds.width,
            height: selectionRect.height / bounds.height
        )
        onFinish?(normalizedRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onFinish?(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let dimmingPath = NSBezierPath(rect: bounds)
        if !selectionRect.isEmpty {
            dimmingPath.appendRect(selectionRect)
            dimmingPath.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.42).setFill()
        dimmingPath.fill()

        guard !selectionRect.isEmpty else { return }

        NSColor.white.setStroke()
        let outerBorder = NSBezierPath(rect: selectionRect.insetBy(dx: -1, dy: -1))
        outerBorder.lineWidth = 2
        outerBorder.stroke()

        NSColor.controlAccentColor.setStroke()
        let innerBorder = NSBezierPath(rect: selectionRect.insetBy(dx: 1, dy: 1))
        innerBorder.lineWidth = 1
        innerBorder.stroke()

        let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.72)
        ]
        let textSize = sizeText.size(withAttributes: attributes)
        let proposedX = selectionRect.midX - textSize.width / 2
        let proposedY = selectionRect.minY - textSize.height - 8
        let origin = CGPoint(
            x: max(8, min(proposedX, bounds.maxX - textSize.width - 8)),
            y: proposedY >= 8 ? proposedY : selectionRect.minY + 8
        )
        sizeText.draw(at: origin, withAttributes: attributes)
    }
}
