import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginItem {
    private(set) var status = SMAppService.mainApp.status
    private(set) var error: String?

    // Outside an app bundle, `swift run`, registering would make the bare build binary open at login.
    let isAvailable = Bundle.main.bundleIdentifier != nil

    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func setOn(_ on: Bool) {
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
    func refresh() {
        status = SMAppService.mainApp.status
    }
}
