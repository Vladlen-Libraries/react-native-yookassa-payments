import UIKit

private class Class { }

enum UserAgentFactory {
    static func makeHeaderValue() -> String {
        let frameworkVersion = Bundle.frameworkVersion
        let osVersion = UIDevice.current.systemVersion
        let deviceClass: String

        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            deviceClass = "Phone"
        case .pad:
            deviceClass = "Tablet"
        default:
            deviceClass = "Unknown"
        }

        let result = [
            "YooKassa.SDK.Client.iOS/",
            frameworkVersion,
            " iOS/",
            osVersion,
            " ",
            deviceClass,
        ].joined()
        return result
    }
}
