import Foundation

enum WindowAction: Int {
    case cascadeSpecificApps = 0
    case tileSpecificApps = 1

    var name: String {
        switch self {
        case .cascadeSpecificApps: return "cascadeSpecificApps"
        case .tileSpecificApps:   return "tileSpecificApps"
        }
    }

    var displayName: String {
        switch self {
        case .cascadeSpecificApps: return "Cascade"
        case .tileSpecificApps:   return "Tile"
        }
    }
}
