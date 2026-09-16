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
SDK_FLAGS=()
if [[ -n "${AUTOPRINT_SDKROOT:-}" ]]; then
  SDK_FLAGS=(-sdk "$AUTOPRINT_SDKROOT")
elif ! echo 'import Combine' | swiftc -sdk "$(xcrun --show-sdk-path)" - -o /dev/null 2>/dev/null; then
  for candidate in /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk \
                   /Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk \
                   /Library/Developer/CommandLineTools/SDKs/MacOSX13.sdk; do
    if [[ -d "$candidate" ]]; then
      echo "Default SDK can't build Foundation/Combine; falling back to $candidate" >&2
      SDK_FLAGS=(-sdk "$candidate")
      break
    fi
  done
fi

swiftc \
  "${SDK_FLAGS[@]}" \
  -o "$BUILD/$EXECUTABLE" \
  $(find AutoPrintMac -name '*.swift' | sort)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AutoPrint.icns"

codesign --force --sign - "$APP"

if [[ "${1:-}" == "--verify" ]]; then
  plutil -lint "$APP/Contents/Info.plist"
  codesign --verify --deep --strict --verbose=2 "$APP"
  spctl --assess --type execute --verbose=4 "$APP" || true
fi

if [[ "${1:-}" != "--no-launch" && "${1:-}" != "--verify" ]]; then
  open -n "$APP"
fi

echo "$APP"
