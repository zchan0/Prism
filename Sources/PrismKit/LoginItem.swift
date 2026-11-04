import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class LoginItem {
    public init() {}

    public private(set) var status = SMAppService.mainApp.status
    public private(set) var error: String?

    // Outside an app bundle, `swift run`, registering would make the bare build binary open at login.
    public let isAvailable = Bundle.main.bundleIdentifier != nil

    public var isOn: Bool { status == .enabled || status == .requiresApproval }

    public func setOn(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }

    // The person can change it in System Settings while the app runs.
    public func refresh() {
        status = SMAppService.mainApp.status
    }
}
