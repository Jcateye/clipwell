import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static var isSupportedInCurrentBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func apply(enabled: Bool) -> Result<String, Error> {
        guard isSupportedInCurrentBundle else {
            return .success("Launch at login is saved, but OS registration requires running from an app bundle.")
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                return .success("Launch at login enabled.")
            } else {
                try SMAppService.mainApp.unregister()
                return .success("Launch at login disabled.")
            }
        } catch {
            return .failure(error)
        }
    }
}
