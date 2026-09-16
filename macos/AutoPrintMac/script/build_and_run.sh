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
