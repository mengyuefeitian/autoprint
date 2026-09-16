# AutoPrint Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the AutoPrint macOS app automatic background update checks plus a one-click "Check for Updates…" menu item, using Sparkle 2.

**Architecture:** Add Sparkle as a SwiftPM dependency, switch the app's build from raw `swiftc` to `swift build` (needed to resolve/link Sparkle), embed `Sparkle.framework` into the app bundle, and add a thin `UpdateService` wrapper around `SPUStandardUpdaterController` wired into the existing menu bar. Distribution uses GitHub Pages (appcast.xml) + GitHub Releases (DMG), mirroring the already-working InceptLaunch project. Publishing a new version to those (i.e., actually making an update visible to users) stays a manual, confirmed step — never automatic.

**Tech Stack:** Swift 6.3.3 (via `/Library/Developer/CommandLineTools` or `~/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain`), SwiftPM, Sparkle 2.6+, AppKit, XCTest (repo convention; cannot execute in this sandbox — see Global Constraints).

**Spec:** `docs/superpowers/specs/2026-09-16-auto-update-design.md`

## Global Constraints

- macOS minimum version: **14.0** — from `Resources/Info.plist`'s `LSMinimumSystemVersion` and `Package.swift`'s `platforms: [.macOS(.v14)]`. Every built binary must embed `minos 14.0` (there is already an automated guard for this in `build_and_run.sh` — keep it working).
- Sparkle version floor: **2.6.0** (`.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")`).
- Repo: `https://github.com/mengyuefeitian/autoprint` (public). GitHub Pages source (once enabled): `main` branch, `/docs` directory. Feed URL: `https://mengyuefeitian.github.io/autoprint/appcast.xml`.
- Signing key: AutoPrint gets its **own** EdDSA key pair, fully independent of the one already used by the sibling `InceptLaunch` project. Generate it with `generate_keys --account autoprint-updates` (the `--account` is required — without it, `generate_keys` reuses/returns whatever key already exists under the default `ed25519` account, which on this machine is InceptLaunch's key). Private key material never goes in git and never stays only in Keychain — export it to a plain, owner-only file at `~/.config/autoprint/sparkle_signing_key` via `generate_keys --account autoprint-updates -x ~/.config/autoprint/sparkle_signing_key`.
- Publishing (`gh release upload`, editing/pushing `docs/appcast.xml`) is never automatic — always state the exact version being published and wait for explicit confirmation first.
- **Local toolchain quirk (this machine):** the default Command Line Tools SDK currently can't compile `import Combine`, and without an explicit deployment target, `swiftc`/`swift build` silently embed whatever OS version the installed compiler defaults to (currently `28.0`, unreleased) instead of `14.0`. `build_and_run.sh` already works around both (SDK fallback to `MacOSX14.4.sdk`, and — for `swift build` specifically — `Package.swift`'s `platforms: [.macOS(.v14)]` is sufficient, no explicit `-target` needed; this was verified directly: `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk swift build` on this repo produces a binary with `minos 14.0`). Preserve this workaround; don't remove it while restructuring the build script.
- **This sandbox has no `XCTest.framework`** (Command-Line-Tools-only install, no Xcode.app), so `swift test` cannot run here at all — it fails before running any test, XCTest or not. Every task below gives an XCTest file (repo convention, will run fine on a machine with a real Xcode/XCTest) *and* a from-scratch verification command that works in this exact sandbox. Do not skip the from-scratch verification just because `swift test` "should" work — it won't, here.

---

## Task 1: Add Sparkle as a Package.swift dependency

**Files:**
- Modify: `macos/AutoPrintMac/Package.swift` (entire file, shown below)

**Interfaces:**
- Produces: the `AutoPrintMac` executable target now has `Sparkle` (module) available to `import`, and the target links with `-rpath @executable_path/../Frameworks` so an embedded `Contents/Frameworks/Sparkle.framework` will be found at runtime.

- [ ] **Step 1: Replace the whole file**

Replace `macos/AutoPrintMac/Package.swift` with:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AutoPrintMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AutoPrintMac", targets: ["AutoPrintMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "AutoPrintMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "AutoPrintMac",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "AutoPrintMacTests",
            dependencies: ["AutoPrintMac"],
            path: "AutoPrintMacTests"
        )
    ]
)
```

(Sparkle's own `Package.swift` only requires swift-tools-version 5.3, so AutoPrint's existing `5.9` doesn't need to change.)

- [ ] **Step 2: Resolve and build to confirm Sparkle fetches cleanly**

Run (from `macos/AutoPrintMac`):

```bash
cd macos/AutoPrintMac
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk swift build
```

Expected: output includes a line fetching `https://github.com/sparkle-project/Sparkle`, resolves to `2.9.x` or similar, and ends with `Build complete!`. If the default SDK on the machine running this doesn't have the Combine problem, `swift build` (no `SDKROOT` override) is fine too — try without the override first; only add it if you see `error: no such module 'Combine'`.

- [ ] **Step 3: Confirm Sparkle.framework was actually built**

```bash
find .build -type d -name "Sparkle.framework"
```

Expected: at least one match (e.g. `.build/arm64-apple-macosx/debug/Sparkle.framework`).

- [ ] **Step 4: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/Package.swift macos/AutoPrintMac/Package.resolved
git commit -m "build(mac): add Sparkle dependency for auto-update

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

(`Package.resolved` is created/updated by `swift build`; include it so the resolved Sparkle version is pinned and reproducible.)

---

## Task 2: Switch build_and_run.sh from raw swiftc to swift build, embed Sparkle.framework

**Files:**
- Modify: `macos/AutoPrintMac/script/build_and_run.sh` (entire file, shown below)

**Interfaces:**
- Consumes: `swift build --show-bin-path` (SwiftPM CLI), the Sparkle dependency from Task 1.
- Produces: `dist/AutoPrint.app` now built via SwiftPM instead of raw `swiftc`, with `Contents/Frameworks/Sparkle.framework` embedded and the whole bundle `codesign --deep` signed (needed because Sparkle.framework itself contains nested executables — `Autoupdate`, `Updater.app`, XPC services — that each need their own signature). No behavior changes for anything else the script does (icon generation, `--no-launch`/`--verify`/default modes, the `minos` guard).

- [ ] **Step 1: Replace the whole file**

Replace `macos/AutoPrintMac/script/build_and_run.sh` with:

```bash
#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.manual-build"
APP="$ROOT/dist/AutoPrint.app"
EXECUTABLE="AutoPrintMac"
ICON="$ROOT/Resources/AutoPrint.icns"

cd "$ROOT"

pkill -f "$APP/Contents/MacOS/$EXECUTABLE" 2>/dev/null || true

mkdir -p "$BUILD" "$ROOT/dist" "$ROOT/Resources"

if [[ ! -f "$ICON" ]]; then
  ICONSET="$BUILD/AutoPrint.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  swift - "$ICONSET" <<'SWIFT'
import AppKit

let iconset = CommandLine.arguments[1]
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.18, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.08, dy: size * 0.08), xRadius: size * 0.2, yRadius: size * 0.2).fill()

    NSColor(calibratedRed: 0.18, green: 0.66, blue: 0.48, alpha: 1).setFill()
    let page = NSBezierPath(roundedRect: NSRect(x: size * 0.26, y: size * 0.30, width: size * 0.48, height: size * 0.44), xRadius: size * 0.04, yRadius: size * 0.04)
    page.fill()

    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.30, y: size * 0.52, width: size * 0.40, height: size * 0.18), xRadius: size * 0.025, yRadius: size * 0.025).fill()

    NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.22, y: size * 0.20, width: size * 0.56, height: size * 0.20), xRadius: size * 0.05, yRadius: size * 0.05).fill()

    image.unlockFocus()
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
SWIFT
  iconutil -c icns "$ICONSET" -o "$ICON"
fi

# Workaround for a known local toolchain issue: a freshly updated Command Line
# Tools SDK can end up mismatched with the installed swiftc (e.g. swiftc reports
# a newer target than the default SDK supports), which breaks even Foundation
# imports like Combine. If the default SDK can't compile a trivial program,
# fall back to an older bundled SDK instead of failing the whole build.
if [[ -z "${AUTOPRINT_SDKROOT:-}" ]] && ! echo 'import Combine' | swiftc -sdk "$(xcrun --show-sdk-path)" - -o /dev/null 2>/dev/null; then
  for candidate in /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk \
                   /Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk \
                   /Library/Developer/CommandLineTools/SDKs/MacOSX13.sdk; do
    if [[ -d "$candidate" ]]; then
      echo "Default SDK can't build Foundation/Combine; falling back to $candidate" >&2
      export AUTOPRINT_SDKROOT="$candidate"
      break
    fi
  done
fi
if [[ -n "${AUTOPRINT_SDKROOT:-}" ]]; then
  export SDKROOT="$AUTOPRINT_SDKROOT"
fi

# Build via SwiftPM (not raw swiftc) so Sparkle's dependency graph resolves.
# Package.swift's `platforms: [.macOS(.v14)]` is what pins the deployment
# target here -- swift build honors it automatically, no explicit -target
# flag needed (verified: even under the SDKROOT fallback above, the built
# binary correctly embeds minos 14.0).
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$EXECUTABLE"

# Guard rail: verify the binary actually embeds the intended minimum OS
# version, so a future toolchain change can't silently ship an app that
# nobody's machine (including this one) can run.
MIN_OS_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT/Resources/Info.plist")"
built_minos="$(otool -l "$BUILD_BINARY" | awk '/^ *minos / { print $2; exit }')"
if [[ "$built_minos" != "$MIN_OS_VERSION" ]]; then
  echo "error: built binary requires macOS $built_minos, expected macOS $MIN_OS_VERSION (LSMinimumSystemVersion in Info.plist)." >&2
  echo "Check that Package.swift's platforms: entry matches Info.plist." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AutoPrint.icns"

# Embed Sparkle.framework -- this project has no Xcode project to do this
# automatically, so the framework must be copied by hand. Package.swift's
# linkerSettings already adds the matching @executable_path/../Frameworks
# rpath so the binary finds it here at runtime.
APP_FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$APP_FRAMEWORKS"
SPARKLE_FRAMEWORK="$(find "$ROOT/.build" -type d -name "Sparkle.framework" -path "*macos*" 2>/dev/null | head -n 1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(find "$ROOT/.build" -type d -name "Sparkle.framework" 2>/dev/null | head -n 1)"
fi
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  rm -rf "$APP_FRAMEWORKS/Sparkle.framework"
  cp -R "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"
else
  echo "error: Sparkle.framework not found under $ROOT/.build -- the app cannot launch without it. Run 'swift build' first." >&2
  exit 1
fi

# --deep signs the nested Sparkle.framework (its Autoupdate tool, Updater.app,
# and XPC services) along with the main bundle.
codesign --force --deep --sign - "$APP"

if [[ "${1:-}" == "--verify" ]]; then
  plutil -lint "$APP/Contents/Info.plist"
  codesign --verify --deep --strict --verbose=2 "$APP"
  spctl --assess --type execute --verbose=4 "$APP" || true
fi

if [[ "${1:-}" != "--no-launch" && "${1:-}" != "--verify" ]]; then
  open -n "$APP"
fi

echo "$APP"
```

- [ ] **Step 2: Build and confirm the app still launches (regression check)**

```bash
cd macos/AutoPrintMac
./script/build_and_run.sh --no-launch
```

Expected: no errors, ends printing the `dist/AutoPrint.app` path. Then:

```bash
open -n dist/AutoPrint.app
sleep 2
ps aux | grep -i AutoPrintMac | grep -v grep
```

Expected: a running `AutoPrintMac` process. Then quit it:

```bash
pkill -f "dist/AutoPrint.app/Contents/MacOS/AutoPrintMac"
```

- [ ] **Step 3: Confirm Sparkle.framework is embedded and signed**

```bash
ls dist/AutoPrint.app/Contents/Frameworks/Sparkle.framework
codesign --verify --deep --strict dist/AutoPrint.app && echo "codesign OK"
otool -l dist/AutoPrint.app/Contents/MacOS/AutoPrintMac | grep -A4 LC_BUILD_VERSION
```

Expected: the framework directory listing succeeds, `codesign OK` prints, and `minos 14.0` (matching `Info.plist`).

- [ ] **Step 4: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/script/build_and_run.sh
git commit -m "build(mac): build via swift build to support Sparkle, embed framework

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: UpdateService (Sparkle wrapper), with tests

**Files:**
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/UpdateService.swift`
- Test: `macos/AutoPrintMac/AutoPrintMacTests/UpdateServiceTests.swift`

**Interfaces:**
- Consumes: `Sparkle` module (from Task 1).
- Produces: `UpdateService` — `init()` (no arguments), `func checkForUpdates()`. `UpdateService.desiredConfiguration: (automaticallyChecksForUpdates: Bool, updateCheckInterval: TimeInterval)` (static). `UpdateService.configure(_ updater: UpdaterConfigurable)` (static). `protocol UpdaterConfigurable: AnyObject` with `var automaticallyChecksForUpdates: Bool { get set }` and `var updateCheckInterval: TimeInterval { get set }`. Task 4 (`MenuBarController`) instantiates `UpdateService()` and calls `.checkForUpdates()`.

- [ ] **Step 1: Write the failing test**

Create `macos/AutoPrintMac/AutoPrintMacTests/UpdateServiceTests.swift`:

```swift
import XCTest
@testable import AutoPrintMac

@MainActor
private final class FakeUpdater: UpdaterConfigurable {
    var automaticallyChecksForUpdates = false
    var updateCheckInterval: TimeInterval = 0
}

final class UpdateServiceTests: XCTestCase {
    func testDesiredConfigurationChecksAutomaticallyOnceDaily() {
        let config = UpdateService.desiredConfiguration
        XCTAssertTrue(config.automaticallyChecksForUpdates, "auto-update must be on by default")
        XCTAssertEqual(config.updateCheckInterval, 86400, "check interval must be once a day")
    }

    @MainActor
    func testConfigureAppliesDesiredConfigurationToAnyUpdater() {
        let fake = FakeUpdater()
        UpdateService.configure(fake)
        XCTAssertTrue(fake.automaticallyChecksForUpdates)
        XCTAssertEqual(fake.updateCheckInterval, 86400)
    }
}
```

- [ ] **Step 2: Verify it fails to compile (UpdateService doesn't exist yet)**

This sandbox has no `XCTest.framework`, so `swift test` cannot run at all here (fails before reaching any test, XCTest or not) — that limitation is orthogonal to whether `UpdateService` exists. Verify the RED state with a from-scratch compile instead, which needs the real Sparkle framework linked:

```bash
cd macos/AutoPrintMac
SPARKLE_FRAMEWORK_DIR="$(dirname "$(find .build -type d -name 'Sparkle.framework' -path '*macos*' | head -n 1)")"
cat > /tmp/update_service_check.swift <<'SWIFT'
import Foundation

@MainActor
private final class FakeUpdater: UpdaterConfigurable {
    var automaticallyChecksForUpdates = false
    var updateCheckInterval: TimeInterval = 0
}

@main
struct Verify {
    @MainActor
    static func main() {
        let config = UpdateService.desiredConfiguration
        expect(config.automaticallyChecksForUpdates, "auto-update must be on by default")
        expect(config.updateCheckInterval == 86400, "check interval must be once a day")

        let fake = FakeUpdater()
        UpdateService.configure(fake)
        expect(fake.automaticallyChecksForUpdates, "configure() must enable automatic checks")
        expect(fake.updateCheckInterval == 86400, "configure() must set the daily interval")

        print("UpdateServiceTests (scratch) passed")
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
SWIFT
swiftc AutoPrintMac/Core/UpdateService.swift /tmp/update_service_check.swift \
  -F "$SPARKLE_FRAMEWORK_DIR" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$SPARKLE_FRAMEWORK_DIR" \
  -o /tmp/update_service_check 2>&1 | tail -20
```

Expected: compile error — `AutoPrintMac/Core/UpdateService.swift` does not exist yet (`error: no such file or directory`). This confirms RED.

- [ ] **Step 3: Write the implementation**

Create `macos/AutoPrintMac/AutoPrintMac/Core/UpdateService.swift`:

```swift
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
        Self.configure(controller.updater)
    }

    /// Manual trigger for the "Check for Updates…" menu item.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
```

- [ ] **Step 4: Verify it passes**

Re-run the exact same compile-and-run command from Step 2:

```bash
cd macos/AutoPrintMac
SPARKLE_FRAMEWORK_DIR="$(dirname "$(find .build -type d -name 'Sparkle.framework' -path '*macos*' | head -n 1)")"
swiftc AutoPrintMac/Core/UpdateService.swift /tmp/update_service_check.swift \
  -F "$SPARKLE_FRAMEWORK_DIR" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$SPARKLE_FRAMEWORK_DIR" \
  -o /tmp/update_service_check
DYLD_FRAMEWORK_PATH="$SPARKLE_FRAMEWORK_DIR" /tmp/update_service_check
```

Expected: `UpdateServiceTests (scratch) passed`.

- [ ] **Step 5: Confirm the real app target still builds with UpdateService.swift in it**

```bash
cd macos/AutoPrintMac
swift build
```

Expected: `Build complete!` with no errors (uses whatever `SDKROOT`/`AUTOPRINT_SDKROOT` is already exported from Task 2's troubleshooting, if needed on this machine).

- [ ] **Step 6: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/AutoPrintMac/Core/UpdateService.swift macos/AutoPrintMac/AutoPrintMacTests/UpdateServiceTests.swift
git commit -m "feat(mac): add UpdateService wrapping Sparkle's standard updater

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Wire "Check for Updates…" into the menu bar

**Files:**
- Modify: `macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift`
- Modify: `macos/AutoPrintMac/AutoPrintMac/UI/Localization.swift`

**Interfaces:**
- Consumes: `UpdateService()` / `.checkForUpdates()` (from Task 3).

- [ ] **Step 1: Add the localization key**

In `macos/AutoPrintMac/AutoPrintMac/UI/Localization.swift`, find:

```swift
    case printNow
    case quit
```

Replace with:

```swift
    case printNow
    case checkForUpdates
    case quit
```

Then find:

```swift
        case .printNow: return choose("立即打印", "Print Now", language)
        case .quit: return choose("退出", "Quit", language)
```

Replace with:

```swift
        case .printNow: return choose("立即打印", "Print Now", language)
        case .checkForUpdates: return choose("检查更新…", "Check for Updates…", language)
        case .quit: return choose("退出", "Quit", language)
```

- [ ] **Step 2: Add the menu item and wire it up**

In `macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift`, find:

```swift
    private var printNowMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
```

Replace with:

```swift
    private var printNowMenuItem: NSMenuItem?
    private var checkForUpdatesMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var updateService: UpdateService?
```

Find:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemIcon()
        AutoPrintEngine.shared.start()
```

Replace with:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemIcon()
        AutoPrintEngine.shared.start()
        updateService = UpdateService()
```

Find:

```swift
        let printNowItem = NSMenuItem(title: "", action: #selector(printNow), keyEquivalent: "r")
        printNowItem.target = self
        menu.addItem(printNowItem)
        printNowMenuItem = printNowItem
        updateMenuTitles()

        menu.addItem(NSMenuItem.separator())
```

Replace with:

```swift
        let printNowItem = NSMenuItem(title: "", action: #selector(printNow), keyEquivalent: "r")
        printNowItem.target = self
        menu.addItem(printNowItem)
        printNowMenuItem = printNowItem

        let checkForUpdatesItem = NSMenuItem(title: "", action: #selector(checkForUpdates), keyEquivalent: "u")
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)
        checkForUpdatesMenuItem = checkForUpdatesItem
        updateMenuTitles()

        menu.addItem(NSMenuItem.separator())
```

Find:

```swift
    @objc private func printNow() {
        AutoPrintEngine.shared.printNow()
    }
```

Replace with:

```swift
    @objc private func printNow() {
        AutoPrintEngine.shared.printNow()
    }

    @objc private func checkForUpdates() {
        updateService?.checkForUpdates()
    }
```

Find:

```swift
        printNowMenuItem?.title = text(.printNow, language: language)
        quitMenuItem?.title = text(.quit, language: language)
```

Replace with:

```swift
        printNowMenuItem?.title = text(.printNow, language: language)
        checkForUpdatesMenuItem?.title = text(.checkForUpdates, language: language)
        quitMenuItem?.title = text(.quit, language: language)
```

- [ ] **Step 3: Build and launch, confirm the menu item is present**

```bash
cd macos/AutoPrintMac
./script/build_and_run.sh --no-launch
open -n dist/AutoPrint.app
sleep 2
```

Then, since this is a menu bar (`LSUIElement`) app with no Dock icon, inspect its menu via the Accessibility API rather than a screenshot:

```bash
osascript -e '
tell application "System Events"
    tell process "AutoPrintMac"
        set menuItems to name of every menu item of menu 1 of (first menu bar item of menu bar 2)
        return menuItems
    end tell
end tell'
```

Expected: the returned list includes `"检查更新…"` (or `"Check for Updates…"` depending on the configured language) alongside the existing items. If this fails because Accessibility permission hasn't been granted to the terminal/agent, instead confirm structurally: `grep -n "checkForUpdatesMenuItem" macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift` shows it wired in all four places (property, creation, action, title update), and rely on Step 4's manual click.

Quit the test instance:

```bash
pkill -f "dist/AutoPrint.app/Contents/MacOS/AutoPrintMac"
```

- [ ] **Step 4: Manual smoke test (cannot be scripted — Sparkle's own UI)**

Launch `dist/AutoPrint.app`, open the menu bar dropdown, click "Check for Updates…". Expected: Sparkle's standard "Checking for updates…" dialog appears, then either "You're up to date" or an error about the feed (expected at this point — `docs/appcast.xml` doesn't exist yet; Task 8 creates it). This confirms the button is wired to a real, running `SPUStandardUpdaterController`, not just that the code compiles.

- [ ] **Step 5: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift macos/AutoPrintMac/AutoPrintMac/UI/Localization.swift
git commit -m "feat(mac): add Check for Updates… menu item

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Generate AutoPrint's Sparkle signing key pair

This is a one-time, manual setup step — no code changes, nothing to commit except a note of the public key value (used in Task 6).

**Files:** none (produces a value used by Task 6, and a local-only private key file not tracked in git).

- [ ] **Step 1: Locate the generate_keys tool**

```bash
cd macos/AutoPrintMac
find .build -iname "generate_keys" -type f
```

Expected: one match, e.g. `.build/artifacts/sparkle/Sparkle/bin/generate_keys`.

- [ ] **Step 2: Generate a new, AutoPrint-specific key pair**

```bash
GENERATE_KEYS=".build/artifacts/sparkle/Sparkle/bin/generate_keys"
"$GENERATE_KEYS" --account autoprint-updates
```

This creates a new Keychain item (distinct from InceptLaunch's default-account key) and prints the public key plus the exact `SUPublicEDKey` Info.plist snippet to use. **Copy the printed public key value** — it's needed verbatim in Task 6.

- [ ] **Step 3: Export the private key to a plain file**

```bash
mkdir -p ~/.config/autoprint
"$GENERATE_KEYS" --account autoprint-updates -x ~/.config/autoprint/sparkle_signing_key
chmod 600 ~/.config/autoprint/sparkle_signing_key
```

- [ ] **Step 4: Confirm it's excluded from git**

```bash
cd /Users/xiaoan/Documents/autoprint
git status --short
```

Expected: `~/.config/autoprint/sparkle_signing_key` is outside the repo entirely (it's under the user's home config dir, not the project directory), so it cannot show up here regardless of `.gitignore`. Confirm nothing under `macos/AutoPrintMac` changed as a side effect of running `generate_keys`.

- [ ] **Step 5: No commit for this task** (nothing in the repo changed).

---

## Task 6: Add Sparkle keys to Info.plist

**Files:**
- Modify: `macos/AutoPrintMac/Resources/Info.plist`

**Interfaces:**
- Consumes: the public key value printed in Task 5, Step 2.

- [ ] **Step 1: Add the four new keys**

In `macos/AutoPrintMac/Resources/Info.plist`, find:

```xml
	<key>LSUIElement</key>
	<true/>
```

Replace with (substituting the real public key from Task 5 for `PASTE_PUBLIC_KEY_HERE`):

```xml
	<key>LSUIElement</key>
	<true/>
	<key>SUFeedURL</key>
	<string>https://mengyuefeitian.github.io/autoprint/appcast.xml</string>
	<key>SUPublicEDKey</key>
	<string>PASTE_PUBLIC_KEY_HERE</string>
	<key>SUEnableAutomaticChecks</key>
	<true/>
	<key>SUScheduledCheckInterval</key>
	<integer>86400</integer>
```

- [ ] **Step 2: Verify the plist is still well-formed**

```bash
plutil -lint macos/AutoPrintMac/Resources/Info.plist
```

Expected: `macos/AutoPrintMac/Resources/Info.plist: OK`.

- [ ] **Step 3: Rebuild and confirm the keys land in the built app**

```bash
cd macos/AutoPrintMac
./script/build_and_run.sh --no-launch
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' dist/AutoPrint.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' dist/AutoPrint.app/Contents/Info.plist
```

Expected: the feed URL and the real (non-placeholder) public key both print correctly.

- [ ] **Step 4: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/Resources/Info.plist
git commit -m "feat(mac): configure Sparkle feed URL and signing public key

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Add script/publish_release.sh

**Files:**
- Create: `macos/AutoPrintMac/script/publish_release.sh`

**Interfaces:**
- Consumes: `~/.config/autoprint/sparkle_signing_key` (Task 5), `dist/AutoPrint.app/Contents/Info.plist`'s `LSMinimumSystemVersion` (Task 6), the `sign_update` tool bundled with Sparkle.
- Produces: printed `<item>` XML for manual pasting into `docs/appcast.xml` (Task 8). Does **not** upload anything or modify any file — publishing stays manual.

- [ ] **Step 1: Create the script**

Create `macos/AutoPrintMac/script/publish_release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Signs a release .dmg with Sparkle's EdDSA key and prints the appcast
# <item> XML to paste into docs/appcast.xml. Manual, per-release — not run
# automatically by release.sh. Requires the private key file exported in
# Task 5 (generate_keys --account autoprint-updates -x <file>) to be present
# at SPARKLE_PRIVATE_KEY_FILE. Deliberately not Keychain-based: the private
# key lives only in a plain, owner-only file outside git, never relied on
# implicitly via Keychain.

VERSION="${1:?Usage: publish_release.sh <version> <path-to-dmg>}"
DMG_PATH="${2:?Usage: publish_release.sh <version> <path-to-dmg>}"

SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$HOME/.config/autoprint/sparkle_signing_key}"
if [ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]; then
  echo "error: private key file not found at $SPARKLE_PRIVATE_KEY_FILE — set SPARKLE_PRIVATE_KEY_FILE or run 'generate_keys --account autoprint-updates -x <file>' first" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prefer the known-correct EdDSA sign_update path (Sparkle ships it
# pre-built inside the resolved package artifacts — it is not an SPM
# product, so it can't be built with `swift build --product sign_update`).
# Fall back to a find-based search (excluding the legacy DSA bash script at
# old_dsa_scripts/sign_update, which takes different arguments) in case the
# exact path shifts in a future Sparkle version.
SIGN_UPDATE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
if [ ! -f "$SIGN_UPDATE" ]; then
  SIGN_UPDATE="$(find "$ROOT_DIR/.build" -name "sign_update" -type f -not -path "*old_dsa_scripts*" | head -n 1)"
fi

if [ -z "$SIGN_UPDATE" ] || [ ! -f "$SIGN_UPDATE" ]; then
  echo "error: sign_update tool not found under .build — run 'swift build' first" >&2
  exit 1
fi

# sign_update's stdout already includes both sparkle:edSignature and length
# attributes — do not add a second length= here, it would produce invalid
# XML (duplicate attribute on the same element).
SIGNATURE_LINE="$("$SIGN_UPDATE" -f "$SPARKLE_PRIVATE_KEY_FILE" "$DMG_PATH")"
DOWNLOAD_URL="https://github.com/mengyuefeitian/autoprint/releases/download/v${VERSION}/$(basename "$DMG_PATH")"

# Derive minimumSystemVersion from the actual built app bundle's
# Info.plist rather than hardcoding it — the built binary's real minimum
# OS requirement is the only reliable source of truth, and a stale
# hardcoded value could cause Sparkle to offer an update to machines that
# can't run it.
APP_BUNDLE="$ROOT_DIR/dist/AutoPrint.app"
APP_INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
if [ ! -d "$APP_BUNDLE" ]; then
  echo "error: $APP_BUNDLE not found — build the app first with 'bash script/build_and_run.sh --no-launch' before running publish_release.sh" >&2
  exit 1
fi
MIN_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP_INFO_PLIST" 2>/dev/null || true)"
if [ -z "$MIN_SYSTEM_VERSION" ]; then
  echo "error: LSMinimumSystemVersion not found in $APP_INFO_PLIST — ensure the app was built via 'bash script/build_and_run.sh' first" >&2
  exit 1
fi

cat <<ITEM

Paste this <item> into docs/appcast.xml, inside <channel>, above any older entries:

    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(date -R)</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL}"
        type="application/octet-stream"
        ${SIGNATURE_LINE} />
    </item>
ITEM
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x macos/AutoPrintMac/script/publish_release.sh
```

- [ ] **Step 3: Dry-run it against the current build**

Requires Task 5's key file and a built app (from Task 6, Step 3) plus a packaged DMG:

```bash
cd macos/AutoPrintMac
./script/package_dmg.sh
./script/publish_release.sh "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" \
  "dist/AutoPrint-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)-local.dmg"
```

Expected: prints a well-formed `<item>...</item>` block with a real `sparkle:edSignature` and `length` attribute (not empty, not an error message).

- [ ] **Step 4: Commit**

```bash
cd /Users/xiaoan/Documents/autoprint
git add macos/AutoPrintMac/script/publish_release.sh
git commit -m "build(mac): add publish_release.sh for signing DMGs and generating appcast entries

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Create docs/appcast.xml and enable GitHub Pages

**Files:**
- Create: `docs/appcast.xml`

**Interfaces:**
- Consumes: nothing from earlier tasks directly (the first real `<item>` gets pasted in during the next actual release, per Task 5's rollout note — not as part of this task).

- [ ] **Step 1: Create the appcast skeleton**

Create `docs/appcast.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>AutoPrint Updates</title>
    <link>https://mengyuefeitian.github.io/autoprint/appcast.xml</link>
    <description>Most recent updates for AutoPrint.</description>
    <language>en</language>
  </channel>
</rss>
```

(No `<item>` yet — the next real `release.sh` + `publish_release.sh` run adds the first one, per the spec's rollout section. This skeleton just makes the feed URL resolve to valid, empty RSS instead of a 404, so Sparkle's "Checking for updates…" call in Task 4 Step 4 fails cleanly with "no update found" rather than a parse error, once Pages is live.)

- [ ] **Step 2: Validate it's well-formed XML**

```bash
xmllint --noout docs/appcast.xml && echo "appcast.xml is valid XML"
```

Expected: `appcast.xml is valid XML`.

- [ ] **Step 3: Commit**

```bash
git add docs/appcast.xml
git commit -m "docs: add initial (empty) Sparkle appcast feed

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Push, then enable GitHub Pages (one-time repo setting)**

```bash
git push origin dev
```

GitHub Pages needs to serve from a branch that has `docs/appcast.xml` — typically `main`. **Before running the next command, confirm with the user whether to merge `dev` into `main` now, or wait until this feature is fully done** — this plan does not decide that on its own. Once the right branch is in place:

```bash
gh api -X POST repos/mengyuefeitian/autoprint/pages \
  -f "source[branch]=main" -f "source[path]=/docs" 2>&1 || \
  echo "If this failed (e.g. Pages already configured, or the gh token lacks the 'pages' scope), enable it manually: https://github.com/mengyuefeitian/autoprint/settings/pages -> Source: Deploy from a branch -> Branch: main, folder: /docs"
```

Expected: either a success response, or (commonly) a permissions error — in which case, tell the user to enable it manually at the URL printed above, since this is a one-time repo setting that doesn't need to be re-run per release.

- [ ] **Step 5: Confirm the feed is actually reachable (may take a few minutes after enabling Pages)**

```bash
curl -sI https://mengyuefeitian.github.io/autoprint/appcast.xml | head -1
```

Expected (eventually — GitHub Pages deploys asynchronously): `HTTP/2 200`. If it 404s immediately after enabling Pages, that's expected — wait a few minutes and retry; do not treat an immediate 404 as a bug in this task's code.

---

## Task 9: End-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Full release.sh run**

```bash
cd macos/AutoPrintMac
./script/release.sh
```

Expected: version bump message, `Build complete!`, DMG path printed, `hdiutil verify` passes.

- [ ] **Step 2: Confirm the shipped binary is safe (minos) and complete (Sparkle embedded, signed)**

```bash
otool -l dist/AutoPrint.app/Contents/MacOS/AutoPrintMac | grep -A4 LC_BUILD_VERSION
codesign --verify --deep --strict dist/AutoPrint.app && echo "codesign OK"
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' dist/AutoPrint.app/Contents/Info.plist
```

Expected: `minos 14.0`, `codesign OK`, and the real feed URL.

- [ ] **Step 3: Launch and confirm it runs + the update menu item works**

```bash
open -n dist/AutoPrint.app
sleep 2
ps aux | grep -i AutoPrintMac | grep -v grep
```

Then manually: open the menu, click "Check for Updates…", confirm Sparkle's dialog appears (result depends on whether `docs/appcast.xml` has a matching-or-newer `<item>` yet — either "up to date" or a found-update prompt are both correct outcomes at this stage; a crash or "cannot connect" is not).

```bash
pkill -f "dist/AutoPrint.app/Contents/MacOS/AutoPrintMac"
```

- [ ] **Step 4: Report to the user**

Summarize: version built, DMG path, confirmation that Sparkle is wired up and the menu item works, and remind them that actually publishing this version (GitHub Release + appcast.xml entry) is a separate step they need to confirm — per Global Constraints, do not do this automatically.
