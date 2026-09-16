import AppKit
import ObjectiveC

/// Maps AutoPrint's language choice to the `.lproj` folder name a
/// third-party framework bundle (Sparkle) ships under, so its own alerts
/// ("检查更新…", download/verify/install progress, error dialogs) can be
/// forced into the right language. Pure and testable, kept separate from
/// the `Bundle` swizzle below.
enum SparkleLocalizationFolder {
    static func folderName(for language: AppLanguage) -> String? {
        switch language {
        case .chinese: return "zh_CN"
        case .english: return nil
        }
    }
}

extension Bundle {
    /// Method-swizzles `localizedString(forKey:value:table:)` process-wide
    /// so any bundle's lookup — ours or a third-party framework's — is
    /// forced through the `.lproj` folder matching AutoPrint's language
    /// choice, when one exists on that bundle.
    ///
    /// This is needed because `Bundle`'s own automatic locale resolution —
    /// used internally by any `NSLocalizedString`-style lookup, including
    /// Sparkle's own update-check alerts — does not honor the standard
    /// `AppleLanguages` override for a bundle other than `Bundle.main`
    /// (this exact workaround was already verified empirically in a
    /// sibling project against the real, signed, dyld-loaded
    /// `Sparkle.framework`: every documented variant of the AppleLanguages
    /// trick left `Bundle.preferredLocalizations` stuck on "en" regardless
    /// of the real system language). Sparkle.framework does ship a
    /// `zh_CN.lproj`, so once lookups are routed through it directly,
    /// its dialogs display in Chinese.
    ///
    /// Safe process-wide: AutoPrint's own UI goes through the custom
    /// `L10n.text(_:language:)` dictionary, not `NSLocalizedString`, so
    /// only third-party bundles (Sparkle) are actually affected.
    private static let activateOnce: Void = {
        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.autoPrint_localizedString(forKey:value:table:))
        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    static func activateSparkleLanguageOverride() {
        _ = activateOnce
    }

    @objc private func autoPrint_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let folder = Bundle.desiredLocalizationFolderName,
           let path = self.path(forResource: folder, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            // Falls through to the original (swapped-in) implementation on
            // languageBundle, since a leaf .lproj bundle has no nested
            // .lproj of its own to match — no infinite recursion.
            return languageBundle.autoPrint_localizedString(forKey: key, value: value, table: tableName)
        }
        // Calling the same selector here invokes the ORIGINAL
        // implementation, since method_exchangeImplementations swapped it
        // in under this selector's name.
        return self.autoPrint_localizedString(forKey: key, value: value, table: tableName)
    }

    /// This swizzled hook can in principle run on any thread that touches
    /// a bundle's localization (AppKit/Foundation/Sparkle internals), so
    /// this is an unsynchronized read of `AppConfigStore`'s `@Published`
    /// property -- in practice safe here because `AppLanguage` is a plain
    /// `String`-backed enum with no associated values (see
    /// `Localization.swift`), so a race can at worst read a value from
    /// just before or after a language change, never a torn/invalid one.
    private static var desiredLocalizationFolderName: String? {
        SparkleLocalizationFolder.folderName(for: AppConfigStore.shared.language)
    }
}
