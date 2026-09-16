#!/bin/bash
# Bumps the patch version + build number, builds the .app, and packages a DMG
# for local install testing. Run this after finishing a round of changes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"

current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"

IFS='.' read -r major minor patch <<< "$current_version"
new_version="$major.$minor.$((patch + 1))"
new_build="$((current_build + 1))"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $new_version" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $new_build" "$PLIST"

echo "Bumped version: $current_version ($current_build) -> $new_version ($new_build)"

"$ROOT/script/build_and_run.sh" --no-launch
DMG_PATH="$("$ROOT/script/package_dmg.sh" "$new_version")"

echo ""
echo "Version:  $new_version ($new_build)"
echo "DMG:      $DMG_PATH"
