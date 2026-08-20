import AppKit
import CoreGraphics

struct DisplayDescriptor: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let frame: CGRect
    let logicalSize: CGSize
    let pixelScale: CGFloat

    var detail: String {
        "\(Int(logicalSize.width)) × \(Int(logicalSize.height)) points"
    }
}

enum DisplayCatalog {
    private static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    static func connectedDisplays() -> [DisplayDescriptor] {
        NSScreen.screens.compactMap { screen in
            guard
                let number = screen.deviceDescription[screenNumberKey] as? NSNumber,
                let uuid = uuidString(for: number.uint32Value)
            else {
                return nil
            }

            let displayID = number.uint32Value
            let logicalSize = screen.frame.size
            let mode = CGDisplayCopyDisplayMode(displayID)
            let scale: CGFloat
            if let mode, mode.width > 0 {
                scale = CGFloat(mode.pixelWidth) / CGFloat(mode.width)
            } else {
                scale = screen.backingScaleFactor
            }

            return DisplayDescriptor(
                id: displayID,
                uuid: uuid,
                name: screen.localizedName,
                frame: screen.frame,
                logicalSize: logicalSize,
                pixelScale: scale
            )
        }
    }

    static func screen(for descriptor: DisplayDescriptor) -> NSScreen? {
        NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[screenNumberKey] as? NSNumber else {
                return false
            }
            return number.uint32Value == descriptor.id
        })
    }

    static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}
