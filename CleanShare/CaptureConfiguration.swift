import CoreGraphics
import Foundation

struct CaptureConfiguration: Codable, Equatable {
    static let storageKey = "captureConfiguration.v1"

    let displayUUID: String
    let displayName: String
    let normalizedX: Double
    let normalizedY: Double
    let normalizedWidth: Double
    let normalizedHeight: Double

    init(display: DisplayDescriptor, normalizedRect: CGRect) {
        let unitRect = normalizedRect.standardized.intersection(
            CGRect(x: 0, y: 0, width: 1, height: 1)
        )

        displayUUID = display.uuid
        displayName = display.name
        normalizedX = unitRect.minX
        normalizedY = unitRect.minY
        normalizedWidth = unitRect.width
        normalizedHeight = unitRect.height
    }

    var normalizedRect: CGRect {
        CGRect(
            x: normalizedX,
            y: normalizedY,
            width: normalizedWidth,
            height: normalizedHeight
        )
    }

    func sourceRect(for display: DisplayDescriptor) -> CGRect {
        CGRect(
            x: normalizedX * display.logicalSize.width,
            y: normalizedY * display.logicalSize.height,
            width: normalizedWidth * display.logicalSize.width,
            height: normalizedHeight * display.logicalSize.height
        ).integral
    }
}

struct CaptureConfigurationStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CaptureConfiguration? {
        guard let data = defaults.data(forKey: CaptureConfiguration.storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(CaptureConfiguration.self, from: data)
    }

    func save(_ configuration: CaptureConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: CaptureConfiguration.storageKey)
    }
}
