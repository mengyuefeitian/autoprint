import Foundation
import Sparkle

/// Minimal surface `UpdateService` needs from an updater, so the
/// configuration logic below can be tested without touching Sparkle's real
/// `SPUUpdater` (which requires a live app host and network access).
@MainActor
protocol UpdaterConfigurable: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var updateCheckInterval: TimeInterval { get set }
}

extension SPUUpdater: UpdaterConfigurable {}

/// Wraps Sparkle's standard updater controller: daily background checks
/// plus an on-demand check for the "Check for Updates…" menu item. All
/// download/verify/install/relaunch UI is Sparkle's own standard alerts —
/// this type owns no UI itself.
@MainActor
final class UpdateService {
    /// One check per day, started automatically at launch.
    ///
    /// `nonisolated` because this is pure, immutable configuration data —
    /// it never touches the real (main-actor-isolated) `SPUUpdater`, so it
    /// can be read and unit tested from any context.
    nonisolated static let desiredConfiguration: (automaticallyChecksForUpdates: Bool, updateCheckInterval: TimeInterval) =
        (automaticallyChecksForUpdates: true, updateCheckInterval: 86400)

    /// Pure decision logic, kept separate from the real `SPUUpdater` so it
    /// can be unit tested without touching real Sparkle state.
    static func configure(_ updater: UpdaterConfigurable) {
        updater.automaticallyChecksForUpdates = desiredConfiguration.automaticallyChecksForUpdates
        updater.updateCheckInterval = desiredConfiguration.updateCheckInterval
    }

    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // Deliberately does NOT call `Self.configure(controller.updater)` here.
        // `automaticallyChecksForUpdates`/`updateCheckInterval` are persisting
        // setters on SPUUpdater — they write to user defaults. Calling
        // `configure` unconditionally on every launch would silently
        // re-enable automatic checks even after a user explicitly disabled
        // them via Sparkle's own settings UI. Info.plist's
        // SUEnableAutomaticChecks/SUScheduledCheckInterval already give
        // Sparkle its initial/default cadence; Sparkle's own persisted
        // defaults handle anything the user changes afterward.
        // `configure(_:)` is kept as pure, tested logic for potential future
        // deliberate use (e.g. a "reset to defaults" action), just not
        // invoked here.
    }

    /// Manual trigger for the "Check for Updates…" menu item.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
