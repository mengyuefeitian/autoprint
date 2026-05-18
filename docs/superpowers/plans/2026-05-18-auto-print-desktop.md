# Auto Print Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build native macOS and Windows desktop apps that monitor configured folders, print supported files in creation-time order, move successful files to `printed`, move failed files to `failed`, and record durable logs.

**Architecture:** The repository contains two native applications: `macos/AutoPrintMac` in SwiftUI/AppKit and `windows/AutoPrintWindows` in .NET 8 WPF. Platform code is separate, but both apps share the same configuration schema, queue state model, retry rules, logging fields, and acceptance fixtures documented under `shared/`.

**Tech Stack:** Swift 5.10+, SwiftUI, AppKit, XCTest, SQLite.swift or GRDB for macOS; .NET 8, WPF, MSTest or xUnit, Microsoft.Data.Sqlite, Windows printing APIs, Office COM automation, and LibreOffice command-line fallback for Windows.

---

## File Structure

Create this structure:

```text
shared/
  config-schema.json
  queue-states.md
  sample-config.macos.json
  sample-config.windows.json
  acceptance-fixtures/README.md
macos/
  AutoPrintMac/
    AutoPrintMac.xcodeproj
    AutoPrintMac/
      App/AutoPrintMacApp.swift
      App/MenuBarController.swift
      Core/AppConfig.swift
      Core/FileScanner.swift
      Core/FileStabilityTracker.swift
      Core/NaturalSort.swift
      Core/PrintQueue.swift
      Core/TaskStore.swift
      Core/PrintLogStore.swift
      Printing/PrinterInfo.swift
      Printing/PrinterDetector.swift
      Printing/PrintAdapter.swift
      Printing/MacPrintAdapter.swift
      UI/StatusView.swift
      UI/SettingsView.swift
      UI/LogsView.swift
      UI/CapabilityView.swift
    AutoPrintMacTests/
      FileScannerTests.swift
      FileStabilityTrackerTests.swift
      NaturalSortTests.swift
      PrintQueueTests.swift
      DestinationMoveTests.swift
windows/
  AutoPrintWindows/
    AutoPrintWindows.sln
    src/AutoPrintWindows.App/
      App.xaml
      App.xaml.cs
      MainWindow.xaml
      MainWindow.xaml.cs
      Tray/TrayIconService.cs
      Views/StatusView.xaml
      Views/SettingsView.xaml
      Views/LogsView.xaml
      Views/CapabilityView.xaml
    src/AutoPrintWindows.Core/
      AppConfig.cs
      FileScanner.cs
      FileStabilityTracker.cs
      NaturalSort.cs
      PrintQueue.cs
      TaskStore.cs
      PrintLogStore.cs
      Printing/PrinterInfo.cs
      Printing/PrinterDetector.cs
      Printing/IPrintAdapter.cs
      Printing/WindowsPrintAdapter.cs
    tests/AutoPrintWindows.Core.Tests/
      FileScannerTests.cs
      FileStabilityTrackerTests.cs
      NaturalSortTests.cs
      PrintQueueTests.cs
      DestinationMoveTests.cs
```

## Task 1: Shared Behavior Contract

**Files:**
- Create: `shared/config-schema.json`
- Create: `shared/queue-states.md`
- Create: `shared/sample-config.macos.json`
- Create: `shared/sample-config.windows.json`
- Create: `shared/acceptance-fixtures/README.md`

- [ ] **Step 1: Create the JSON config schema**

Create `shared/config-schema.json` with:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "AutoPrintConfig",
  "type": "object",
  "required": [
    "watchFolders",
    "printerName",
    "scanIntervalSeconds",
    "fileStableSeconds",
    "maxRetries",
    "printedFolderName",
    "failedFolderName",
    "launchAtLogin",
    "autoPrintEnabled"
  ],
  "properties": {
    "watchFolders": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["path", "enabled"],
        "properties": {
          "path": { "type": "string", "minLength": 1 },
          "enabled": { "type": "boolean" }
        },
        "additionalProperties": false
      }
    },
    "printerName": { "type": "string", "minLength": 1 },
    "scanIntervalSeconds": { "type": "integer", "minimum": 5, "default": 30 },
    "fileStableSeconds": { "type": "integer", "minimum": 1, "default": 10 },
    "maxRetries": { "type": "integer", "minimum": 0, "maximum": 10, "default": 3 },
    "printedFolderName": { "type": "string", "minLength": 1, "default": "printed" },
    "failedFolderName": { "type": "string", "minLength": 1, "default": "failed" },
    "launchAtLogin": { "type": "boolean", "default": false },
    "autoPrintEnabled": { "type": "boolean", "default": true }
  },
  "additionalProperties": false
}
```

- [ ] **Step 2: Document queue states**

Create `shared/queue-states.md` with the canonical state list and transitions:

```markdown
# Queue States

Allowed states:

- Pending
- Stabilizing
- Queued
- Printing
- Submitted
- Printed
- Retrying
- Failed

Successful transition:

Pending -> Stabilizing -> Queued -> Printing -> Submitted -> Printed

Retry transition:

Pending -> Stabilizing -> Queued -> Printing -> Retrying -> Queued

Failure transition:

Pending -> Stabilizing -> Queued -> Printing -> Retrying -> Failed
Pending -> Stabilizing -> Failed
```

- [ ] **Step 3: Create sample configs**

Create `shared/sample-config.macos.json`:

```json
{
  "watchFolders": [
    {
      "path": "/Users/example/PrintInbox",
      "enabled": true
    }
  ],
  "printerName": "Office Printer",
  "scanIntervalSeconds": 30,
  "fileStableSeconds": 10,
  "maxRetries": 3,
  "printedFolderName": "printed",
  "failedFolderName": "failed",
  "launchAtLogin": false,
  "autoPrintEnabled": true
}
```

Create `shared/sample-config.windows.json`:

```json
{
  "watchFolders": [
    {
      "path": "C:\\Users\\example\\PrintInbox",
      "enabled": true
    }
  ],
  "printerName": "Office Printer",
  "scanIntervalSeconds": 30,
  "fileStableSeconds": 10,
  "maxRetries": 3,
  "printedFolderName": "printed",
  "failedFolderName": "failed",
  "launchAtLogin": false,
  "autoPrintEnabled": true
}
```

- [ ] **Step 4: Create acceptance fixture instructions**

Create `shared/acceptance-fixtures/README.md`:

```markdown
# Acceptance Fixtures

Use a real or virtual local printer for manual acceptance.

Prepare these files in a clean watch folder:

- 001-oldest.pdf
- 002-image.png
- 003-word.docx
- 004-excel.xlsx
- 005-powerpoint.pptx

Set their creation times in ascending order. Start automatic printing and confirm:

- Files are submitted oldest first.
- Successful files move to `printed`.
- Failed files retry three times and move to `failed`.
- Logs include file name, original path, final path, printer name, status, completion time, retry count, and error message when relevant.
```

- [ ] **Step 5: Commit shared contract**

Run:

```bash
git add shared
git commit -m "docs: add shared auto print behavior contract"
```

Expected: commit succeeds.

## Task 2: macOS Project Skeleton

**Files:**
- Create: `macos/AutoPrintMac/AutoPrintMac.xcodeproj`
- Create: `macos/AutoPrintMac/AutoPrintMac/App/AutoPrintMacApp.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift`
- Create: `macos/AutoPrintMac/AutoPrintMacTests/NaturalSortTests.swift`

- [ ] **Step 1: Create an Xcode macOS app project**

Run from the repository root:

```bash
mkdir -p macos
```

Create a macOS App project named `AutoPrintMac` in `macos/` using Xcode with:

- Interface: SwiftUI
- Language: Swift
- Tests: enabled
- Bundle identifier: `com.local.autoprint.mac`

Expected: `macos/AutoPrintMac/AutoPrintMac.xcodeproj` exists.

- [ ] **Step 2: Add app entry**

Create `macos/AutoPrintMac/AutoPrintMac/App/AutoPrintMacApp.swift`:

```swift
import SwiftUI

@main
struct AutoPrintMacApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 3: Add menu bar controller**

Create `macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift`:

```swift
import AppKit

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Auto Print"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Pause Printing", action: #selector(togglePrinting), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func togglePrinting() {
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 4: Build the empty app**

Run:

```bash
xcodebuild -project macos/AutoPrintMac/AutoPrintMac.xcodeproj -scheme AutoPrintMac -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit macOS skeleton**

Run:

```bash
git add macos/AutoPrintMac
git commit -m "feat(mac): add menu bar app skeleton"
```

Expected: commit succeeds.

## Task 3: macOS Core Queue Logic

**Files:**
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/AppConfig.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/NaturalSort.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/FileScanner.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/FileStabilityTracker.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/PrintQueue.swift`
- Test: `macos/AutoPrintMac/AutoPrintMacTests/NaturalSortTests.swift`
- Test: `macos/AutoPrintMac/AutoPrintMacTests/FileStabilityTrackerTests.swift`
- Test: `macos/AutoPrintMac/AutoPrintMacTests/PrintQueueTests.swift`

- [ ] **Step 1: Write natural sort tests**

Create `NaturalSortTests.swift`:

```swift
import XCTest
@testable import AutoPrintMac

final class NaturalSortTests: XCTestCase {
    func testSortsNumberedNamesNaturally() {
        let names = ["10.pdf", "2.pdf", "1.pdf"]
        XCTAssertEqual(names.sorted(by: naturalLessThan), ["1.pdf", "2.pdf", "10.pdf"])
    }
}
```

- [ ] **Step 2: Implement natural sort**

Create `NaturalSort.swift`:

```swift
import Foundation

func naturalLessThan(_ lhs: String, _ rhs: String) -> Bool {
    lhs.compare(rhs, options: [.numeric, .caseInsensitive], locale: .current) == .orderedAscending
}
```

- [ ] **Step 3: Add config model**

Create `AppConfig.swift`:

```swift
import Foundation

struct WatchFolder: Codable, Equatable, Identifiable {
    var id: String { path }
    let path: String
    var enabled: Bool
}

struct AppConfig: Codable, Equatable {
    var watchFolders: [WatchFolder]
    var printerName: String
    var scanIntervalSeconds: Int
    var fileStableSeconds: Int
    var maxRetries: Int
    var printedFolderName: String
    var failedFolderName: String
    var launchAtLogin: Bool
    var autoPrintEnabled: Bool

    static let defaultValue = AppConfig(
        watchFolders: [],
        printerName: "",
        scanIntervalSeconds: 30,
        fileStableSeconds: 10,
        maxRetries: 3,
        printedFolderName: "printed",
        failedFolderName: "failed",
        launchAtLogin: false,
        autoPrintEnabled: true
    )
}
```

- [ ] **Step 4: Add file stability test**

Create `FileStabilityTrackerTests.swift`:

```swift
import XCTest
@testable import AutoPrintMac

final class FileStabilityTrackerTests: XCTestCase {
    func testFileBecomesStableOnlyAfterUnchangedWindow() {
        let tracker = FileStabilityTracker(stableSeconds: 10)
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        tracker.observe(url: url, size: 100, modifiedAt: Date(timeIntervalSince1970: 10), now: Date(timeIntervalSince1970: 20))
        XCTAssertFalse(tracker.isStable(url: url, size: 100, modifiedAt: Date(timeIntervalSince1970: 10), now: Date(timeIntervalSince1970: 29)))
        XCTAssertTrue(tracker.isStable(url: url, size: 100, modifiedAt: Date(timeIntervalSince1970: 10), now: Date(timeIntervalSince1970: 30)))
    }
}
```

- [ ] **Step 5: Implement file stability tracker**

Create `FileStabilityTracker.swift`:

```swift
import Foundation

final class FileStabilityTracker {
    private struct Snapshot {
        let size: UInt64
        let modifiedAt: Date
        let firstSeenStableAt: Date
    }

    private let stableSeconds: TimeInterval
    private var snapshots: [URL: Snapshot] = [:]

    init(stableSeconds: Int) {
        self.stableSeconds = TimeInterval(stableSeconds)
    }

    func observe(url: URL, size: UInt64, modifiedAt: Date, now: Date) {
        snapshots[url] = Snapshot(size: size, modifiedAt: modifiedAt, firstSeenStableAt: now)
    }

    func isStable(url: URL, size: UInt64, modifiedAt: Date, now: Date) -> Bool {
        guard let snapshot = snapshots[url] else {
            observe(url: url, size: size, modifiedAt: modifiedAt, now: now)
            return false
        }

        if snapshot.size != size || snapshot.modifiedAt != modifiedAt {
            snapshots[url] = Snapshot(size: size, modifiedAt: modifiedAt, firstSeenStableAt: now)
            return false
        }

        return now.timeIntervalSince(snapshot.firstSeenStableAt) >= stableSeconds
    }
}
```

- [ ] **Step 6: Implement scanner and queue**

Create `FileScanner.swift` and `PrintQueue.swift` with:

```swift
import Foundation

struct DiscoveredFile: Equatable {
    let url: URL
    let fileName: String
    let createdAt: Date
    let modifiedAt: Date
    let size: UInt64
}

final class FileScanner {
    func scan(config: AppConfig) throws -> [DiscoveredFile] {
        let manager = FileManager.default
        var files: [DiscoveredFile] = []

        for folder in config.watchFolders where folder.enabled {
            let root = URL(fileURLWithPath: folder.path)
            let printed = root.appendingPathComponent(config.printedFolderName).standardizedFileURL
            let failed = root.appendingPathComponent(config.failedFolderName).standardizedFileURL
            let children = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isDirectoryKey, .isHiddenKey])

            for url in children {
                let values = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isDirectoryKey, .isHiddenKey])
                if values.isDirectory == true || values.isHidden == true { continue }
                if url.standardizedFileURL.path.hasPrefix(printed.path) || url.standardizedFileURL.path.hasPrefix(failed.path) { continue }
                if url.lastPathComponent.hasPrefix("~$") { continue }

                files.append(DiscoveredFile(
                    url: url,
                    fileName: url.lastPathComponent,
                    createdAt: values.creationDate ?? Date.distantPast,
                    modifiedAt: values.contentModificationDate ?? Date.distantPast,
                    size: UInt64(values.fileSize ?? 0)
                ))
            }
        }

        return files.sorted {
            if $0.createdAt == $1.createdAt {
                return naturalLessThan($0.fileName, $1.fileName)
            }
            return $0.createdAt < $1.createdAt
        }
    }
}
```

```swift
import Foundation

enum PrintTaskState: String, Codable {
    case pending = "Pending"
    case stabilizing = "Stabilizing"
    case queued = "Queued"
    case printing = "Printing"
    case submitted = "Submitted"
    case printed = "Printed"
    case retrying = "Retrying"
    case failed = "Failed"
}

struct PrintTask: Identifiable, Equatable {
    let id: UUID
    let file: DiscoveredFile
    var state: PrintTaskState
    var retryCount: Int
    var lastError: String?
}

final class PrintQueue {
    private(set) var tasks: [PrintTask] = []

    func replaceQueuedFiles(_ files: [DiscoveredFile]) {
        let existing = Set(tasks.map { $0.file.url })
        let newTasks = files
            .filter { !existing.contains($0.url) }
            .map { PrintTask(id: UUID(), file: $0, state: .queued, retryCount: 0, lastError: nil) }
        tasks.append(contentsOf: newTasks)
        tasks.sort {
            if $0.file.createdAt == $1.file.createdAt {
                return naturalLessThan($0.file.fileName, $1.file.fileName)
            }
            return $0.file.createdAt < $1.file.createdAt
        }
    }

    func nextTask() -> PrintTask? {
        tasks.first { $0.state == .queued }
    }
}
```

- [ ] **Step 7: Run macOS core tests**

Run:

```bash
xcodebuild test -project macos/AutoPrintMac/AutoPrintMac.xcodeproj -scheme AutoPrintMac -destination 'platform=macOS'
```

Expected: natural sort, stability, scanner, and queue tests pass.

- [ ] **Step 8: Commit macOS core**

Run:

```bash
git add macos/AutoPrintMac
git commit -m "feat(mac): add scan and queue core"
```

Expected: commit succeeds.

## Task 4: macOS Stores, Move Handling, And Printing Adapter

**Files:**
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/TaskStore.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Core/PrintLogStore.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Printing/PrinterInfo.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Printing/PrinterDetector.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Printing/PrintAdapter.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/Printing/MacPrintAdapter.swift`
- Test: `macos/AutoPrintMac/AutoPrintMacTests/DestinationMoveTests.swift`

- [ ] **Step 1: Add destination move test**

Create `DestinationMoveTests.swift`:

```swift
import XCTest
@testable import AutoPrintMac

final class DestinationMoveTests: XCTestCase {
    func testDuplicateDestinationGetsTimestampSuffix() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let printed = root.appendingPathComponent("printed")
        try FileManager.default.createDirectory(at: printed, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("invoice.pdf")
        let existing = printed.appendingPathComponent("invoice.pdf")
        try Data("a".utf8).write(to: source)
        try Data("b".utf8).write(to: existing)

        let moved = try DestinationMover.move(source, into: printed, now: Date(timeIntervalSince1970: 1710000000))

        XCTAssertEqual(moved.lastPathComponent, "invoice-20240309-160000.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
    }
}
```

- [ ] **Step 2: Implement destination mover**

Add `DestinationMover` to `TaskStore.swift`:

```swift
import Foundation

enum DestinationMover {
    static func move(_ source: URL, into directory: URL, now: Date = Date()) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = directory.appendingPathComponent(source.lastPathComponent)
        let destination: URL

        if manager.fileExists(atPath: original.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let base = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            let name = ext.isEmpty ? "\(base)-\(formatter.string(from: now))" : "\(base)-\(formatter.string(from: now)).\(ext)"
            destination = directory.appendingPathComponent(name)
        } else {
            destination = original
        }

        try manager.moveItem(at: source, to: destination)
        return destination
    }
}
```

- [ ] **Step 3: Add print adapter protocol and macOS implementation**

Create `PrintAdapter.swift`:

```swift
import Foundation

protocol PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds: Int) async throws
}

enum PrintAdapterError: Error, LocalizedError {
    case unsupportedType(String)
    case commandFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext): return "Unsupported file type: \(ext)"
        case .commandFailed(let message): return message
        case .timedOut: return "Print command timed out"
        }
    }
}
```

Create `MacPrintAdapter.swift`:

```swift
import Foundation

final class MacPrintAdapter: PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds: Int = 120) async throws {
        let ext = file.pathExtension.lowercased()
        switch ext {
        case "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic":
            try await run("/usr/bin/lp", ["-d", printerName, file.path], timeoutSeconds: timeoutSeconds)
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            try await printWithLibreOffice(file: file, printerName: printerName, timeoutSeconds: timeoutSeconds)
        default:
            throw PrintAdapterError.unsupportedType(ext)
        }
    }

    private func printWithLibreOffice(file: URL, printerName: String, timeoutSeconds: Int) async throws {
        let candidates = [
            "/Applications/LibreOffice.app/Contents/MacOS/soffice",
            "/opt/homebrew/bin/libreoffice",
            "/usr/local/bin/libreoffice"
        ]
        guard let command = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PrintAdapterError.commandFailed("LibreOffice is not installed or not executable")
        }
        try await run(command, ["--headless", "--pt", printerName, file.path], timeoutSeconds: timeoutSeconds)
    }

    private func run(_ launchPath: String, _ arguments: [String], timeoutSeconds: Int) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw PrintAdapterError.commandFailed("\(launchPath) exited with status \(process.terminationStatus)")
        }
    }
}
```

- [ ] **Step 4: Add printer detector**

Create `PrinterDetector.swift`:

```swift
import AppKit

struct PrinterInfo: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let isAvailable: Bool
    let reason: String?
}

final class PrinterDetector {
    func printers() -> [PrinterInfo] {
        NSPrinter.printerNames.map { PrinterInfo(name: $0, isAvailable: true, reason: nil) }
    }

    func find(name: String) -> PrinterInfo {
        if NSPrinter.printerNames.contains(name) {
            return PrinterInfo(name: name, isAvailable: true, reason: nil)
        }
        return PrinterInfo(name: name, isAvailable: false, reason: "Printer was not found")
    }
}
```

- [ ] **Step 5: Run macOS tests**

Run:

```bash
xcodebuild test -project macos/AutoPrintMac/AutoPrintMac.xcodeproj -scheme AutoPrintMac -destination 'platform=macOS'
```

Expected: all tests pass.

- [ ] **Step 6: Commit macOS print infrastructure**

Run:

```bash
git add macos/AutoPrintMac
git commit -m "feat(mac): add print adapter and file movement"
```

Expected: commit succeeds.

## Task 5: macOS UI And Background Loop

**Files:**
- Create: `macos/AutoPrintMac/AutoPrintMac/UI/StatusView.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/UI/SettingsView.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/UI/LogsView.swift`
- Create: `macos/AutoPrintMac/AutoPrintMac/UI/CapabilityView.swift`
- Modify: `macos/AutoPrintMac/AutoPrintMac/App/MenuBarController.swift`

- [ ] **Step 1: Add settings view**

Create `SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @State private var config = AppConfig.defaultValue

    var body: some View {
        TabView {
            StatusView(config: config)
                .tabItem { Text("Status") }
            VStack(alignment: .leading) {
                Toggle("Automatic printing", isOn: $config.autoPrintEnabled)
                TextField("Printer", text: $config.printerName)
                Stepper("Scan interval: \(config.scanIntervalSeconds)s", value: $config.scanIntervalSeconds, in: 5...3600)
                Stepper("Stable wait: \(config.fileStableSeconds)s", value: $config.fileStableSeconds, in: 1...600)
                Stepper("Retries: \(config.maxRetries)", value: $config.maxRetries, in: 0...10)
            }
            .padding()
            .tabItem { Text("Settings") }
            LogsView()
                .tabItem { Text("Logs") }
            CapabilityView()
                .tabItem { Text("Capabilities") }
        }
        .frame(width: 720, height: 460)
    }
}
```

- [ ] **Step 2: Add status, logs, and capability views**

Create `StatusView.swift`:

```swift
import SwiftUI

struct StatusView: View {
    let config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(config.autoPrintEnabled ? "Running" : "Paused").font(.title2)
            Text("Printer: \(config.printerName.isEmpty ? "Not selected" : config.printerName)")
            Text("Watch folders: \(config.watchFolders.count)")
            Text("Scan interval: \(config.scanIntervalSeconds)s")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

Create `LogsView.swift`:

```swift
import SwiftUI

struct LogsView: View {
    var body: some View {
        Text("No print logs yet")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

Create `CapabilityView.swift`:

```swift
import SwiftUI

struct CapabilityView: View {
    var body: some View {
        List {
            Text("Printer: select a printer to check")
            Text("PDF: available through system print path")
            Text("Images: available through system print path")
            Text("Office: requires Microsoft Office or LibreOffice")
        }
    }
}
```

- [ ] **Step 3: Wire menu actions to settings**

Update `MenuBarController.swift` so `Open Settings` displays the settings window and `Pause Printing` toggles the persisted `autoPrintEnabled` value after the config store exists. Until the config store is wired, keep the action no-op and do not crash.

- [ ] **Step 4: Build macOS app**

Run:

```bash
xcodebuild -project macos/AutoPrintMac/AutoPrintMac.xcodeproj -scheme AutoPrintMac -destination 'platform=macOS' build
```

Expected: build succeeds and the menu bar item appears when launched from Xcode.

- [ ] **Step 5: Commit macOS UI**

Run:

```bash
git add macos/AutoPrintMac
git commit -m "feat(mac): add settings and status UI"
```

Expected: commit succeeds.

## Task 6: Windows Project Skeleton

**Files:**
- Create: `windows/AutoPrintWindows/AutoPrintWindows.sln`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/AutoPrintWindows.Core.csproj`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/AutoPrintWindows.App.csproj`
- Create: `windows/AutoPrintWindows/tests/AutoPrintWindows.Core.Tests/AutoPrintWindows.Core.Tests.csproj`

- [ ] **Step 1: Create solution on a Windows machine**

Run in PowerShell from the repository root:

```powershell
mkdir windows\AutoPrintWindows
cd windows\AutoPrintWindows
dotnet new sln -n AutoPrintWindows
dotnet new classlib -n AutoPrintWindows.Core -o src\AutoPrintWindows.Core -f net8.0
dotnet new wpf -n AutoPrintWindows.App -o src\AutoPrintWindows.App -f net8.0-windows
dotnet new xunit -n AutoPrintWindows.Core.Tests -o tests\AutoPrintWindows.Core.Tests -f net8.0
dotnet sln add src\AutoPrintWindows.Core\AutoPrintWindows.Core.csproj
dotnet sln add src\AutoPrintWindows.App\AutoPrintWindows.App.csproj
dotnet sln add tests\AutoPrintWindows.Core.Tests\AutoPrintWindows.Core.Tests.csproj
dotnet add src\AutoPrintWindows.App\AutoPrintWindows.App.csproj reference src\AutoPrintWindows.Core\AutoPrintWindows.Core.csproj
dotnet add tests\AutoPrintWindows.Core.Tests\AutoPrintWindows.Core.Tests.csproj reference src\AutoPrintWindows.Core\AutoPrintWindows.Core.csproj
dotnet add src\AutoPrintWindows.Core\AutoPrintWindows.Core.csproj package Microsoft.Data.Sqlite
```

Expected: solution and projects are created.

- [ ] **Step 2: Build solution**

Run:

```powershell
dotnet build windows\AutoPrintWindows\AutoPrintWindows.sln
```

Expected: build succeeds.

- [ ] **Step 3: Commit Windows skeleton**

Run:

```powershell
git add windows\AutoPrintWindows
git commit -m "feat(windows): add WPF app skeleton"
```

Expected: commit succeeds.

## Task 7: Windows Core Queue Logic

**Files:**
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/AppConfig.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/NaturalSort.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/FileScanner.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/FileStabilityTracker.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/PrintQueue.cs`
- Test: `windows/AutoPrintWindows/tests/AutoPrintWindows.Core.Tests/NaturalSortTests.cs`
- Test: `windows/AutoPrintWindows/tests/AutoPrintWindows.Core.Tests/FileStabilityTrackerTests.cs`
- Test: `windows/AutoPrintWindows/tests/AutoPrintWindows.Core.Tests/PrintQueueTests.cs`

- [ ] **Step 1: Add natural sort test**

Create `NaturalSortTests.cs`:

```csharp
using AutoPrintWindows.Core;

namespace AutoPrintWindows.Core.Tests;

public sealed class NaturalSortTests
{
    [Fact]
    public void SortsNumberedNamesNaturally()
    {
        var names = new[] { "10.pdf", "2.pdf", "1.pdf" };
        Array.Sort(names, NaturalSort.Compare);
        Assert.Equal(new[] { "1.pdf", "2.pdf", "10.pdf" }, names);
    }
}
```

- [ ] **Step 2: Implement natural sort**

Create `NaturalSort.cs`:

```csharp
using System.Runtime.InteropServices;

namespace AutoPrintWindows.Core;

public static partial class NaturalSort
{
    [LibraryImport("shlwapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int StrCmpLogicalW(string x, string y);

    public static int Compare(string? left, string? right)
    {
        return StrCmpLogicalW(left ?? string.Empty, right ?? string.Empty);
    }
}
```

- [ ] **Step 3: Add config and queue models**

Create `AppConfig.cs`:

```csharp
namespace AutoPrintWindows.Core;

public sealed record WatchFolder(string Path, bool Enabled);

public sealed record AppConfig(
    IReadOnlyList<WatchFolder> WatchFolders,
    string PrinterName,
    int ScanIntervalSeconds,
    int FileStableSeconds,
    int MaxRetries,
    string PrintedFolderName,
    string FailedFolderName,
    bool LaunchAtLogin,
    bool AutoPrintEnabled)
{
    public static AppConfig Default { get; } = new(
        Array.Empty<WatchFolder>(),
        string.Empty,
        30,
        10,
        3,
        "printed",
        "failed",
        false,
        true);
}
```

Create `PrintQueue.cs`:

```csharp
namespace AutoPrintWindows.Core;

public enum PrintTaskState
{
    Pending,
    Stabilizing,
    Queued,
    Printing,
    Submitted,
    Printed,
    Retrying,
    Failed
}

public sealed record DiscoveredFile(
    string Path,
    string FileName,
    DateTimeOffset CreatedAt,
    DateTimeOffset ModifiedAt,
    long Size);

public sealed record PrintTask(
    Guid Id,
    DiscoveredFile File,
    PrintTaskState State,
    int RetryCount,
    string? LastError);

public sealed class PrintQueue
{
    private readonly List<PrintTask> _tasks = [];

    public IReadOnlyList<PrintTask> Tasks => _tasks;

    public void ReplaceQueuedFiles(IEnumerable<DiscoveredFile> files)
    {
        var existing = _tasks.Select(t => t.File.Path).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var file in files.Where(file => !existing.Contains(file.Path)))
        {
            _tasks.Add(new PrintTask(Guid.NewGuid(), file, PrintTaskState.Queued, 0, null));
        }

        _tasks.Sort((left, right) =>
        {
            var byDate = left.File.CreatedAt.CompareTo(right.File.CreatedAt);
            return byDate != 0 ? byDate : NaturalSort.Compare(left.File.FileName, right.File.FileName);
        });
    }

    public PrintTask? NextTask() => _tasks.FirstOrDefault(t => t.State == PrintTaskState.Queued);
}
```

- [ ] **Step 4: Add stability tracker**

Create `FileStabilityTracker.cs`:

```csharp
namespace AutoPrintWindows.Core;

public sealed class FileStabilityTracker
{
    private sealed record Snapshot(long Size, DateTimeOffset ModifiedAt, DateTimeOffset FirstSeenStableAt);
    private readonly TimeSpan _stableWindow;
    private readonly Dictionary<string, Snapshot> _snapshots = new(StringComparer.OrdinalIgnoreCase);

    public FileStabilityTracker(int stableSeconds)
    {
        _stableWindow = TimeSpan.FromSeconds(stableSeconds);
    }

    public void Observe(string path, long size, DateTimeOffset modifiedAt, DateTimeOffset now)
    {
        _snapshots[path] = new Snapshot(size, modifiedAt, now);
    }

    public bool IsStable(string path, long size, DateTimeOffset modifiedAt, DateTimeOffset now)
    {
        if (!_snapshots.TryGetValue(path, out var snapshot))
        {
            Observe(path, size, modifiedAt, now);
            return false;
        }

        if (snapshot.Size != size || snapshot.ModifiedAt != modifiedAt)
        {
            Observe(path, size, modifiedAt, now);
            return false;
        }

        return now - snapshot.FirstSeenStableAt >= _stableWindow;
    }
}
```

- [ ] **Step 5: Add scanner**

Create `FileScanner.cs`:

```csharp
namespace AutoPrintWindows.Core;

public sealed class FileScanner
{
    public IReadOnlyList<DiscoveredFile> Scan(AppConfig config)
    {
        var files = new List<DiscoveredFile>();

        foreach (var folder in config.WatchFolders.Where(f => f.Enabled))
        {
            if (!Directory.Exists(folder.Path))
            {
                continue;
            }

            var printed = Path.GetFullPath(Path.Combine(folder.Path, config.PrintedFolderName));
            var failed = Path.GetFullPath(Path.Combine(folder.Path, config.FailedFolderName));

            foreach (var path in Directory.EnumerateFiles(folder.Path))
            {
                var fullPath = Path.GetFullPath(path);
                if (fullPath.StartsWith(printed, StringComparison.OrdinalIgnoreCase) ||
                    fullPath.StartsWith(failed, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var name = Path.GetFileName(fullPath);
                if (name.StartsWith("~$", StringComparison.Ordinal) || name.StartsWith(".", StringComparison.Ordinal))
                {
                    continue;
                }

                var info = new FileInfo(fullPath);
                files.Add(new DiscoveredFile(
                    fullPath,
                    name,
                    info.CreationTimeUtc,
                    info.LastWriteTimeUtc,
                    info.Length));
            }
        }

        files.Sort((left, right) =>
        {
            var byDate = left.CreatedAt.CompareTo(right.CreatedAt);
            return byDate != 0 ? byDate : NaturalSort.Compare(left.FileName, right.FileName);
        });
        return files;
    }
}
```

- [ ] **Step 6: Run Windows core tests**

Run on Windows:

```powershell
dotnet test windows\AutoPrintWindows\AutoPrintWindows.sln
```

Expected: all core tests pass.

- [ ] **Step 7: Commit Windows core**

Run:

```powershell
git add windows\AutoPrintWindows
git commit -m "feat(windows): add scan and queue core"
```

Expected: commit succeeds.

## Task 8: Windows Stores, Move Handling, And Printing Adapter

**Files:**
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/TaskStore.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/PrintLogStore.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/Printing/PrinterInfo.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/Printing/PrinterDetector.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/Printing/IPrintAdapter.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.Core/Printing/WindowsPrintAdapter.cs`
- Test: `windows/AutoPrintWindows/tests/AutoPrintWindows.Core.Tests/DestinationMoveTests.cs`

- [ ] **Step 1: Implement destination mover**

Create `TaskStore.cs` with:

```csharp
namespace AutoPrintWindows.Core;

public static class DestinationMover
{
    public static string Move(string source, string directory, DateTimeOffset? now = null)
    {
        Directory.CreateDirectory(directory);
        var original = Path.Combine(directory, Path.GetFileName(source));
        var destination = original;

        if (File.Exists(destination))
        {
            var stamp = (now ?? DateTimeOffset.UtcNow).UtcDateTime.ToString("yyyyMMdd-HHmmss");
            var name = Path.GetFileNameWithoutExtension(source);
            var ext = Path.GetExtension(source);
            destination = Path.Combine(directory, $"{name}-{stamp}{ext}");
        }

        File.Move(source, destination);
        return destination;
    }
}
```

- [ ] **Step 2: Add print adapter interface**

Create `Printing/IPrintAdapter.cs`:

```csharp
namespace AutoPrintWindows.Core.Printing;

public interface IPrintAdapter
{
    Task PrintAsync(string filePath, string printerName, TimeSpan timeout, CancellationToken cancellationToken);
}
```

- [ ] **Step 3: Add Windows print adapter**

Create `Printing/WindowsPrintAdapter.cs`:

```csharp
using System.Diagnostics;

namespace AutoPrintWindows.Core.Printing;

public sealed class WindowsPrintAdapter : IPrintAdapter
{
    public async Task PrintAsync(string filePath, string printerName, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(filePath).ToLowerInvariant();
        if (extension is ".doc" or ".docx" or ".xls" or ".xlsx" or ".ppt" or ".pptx")
        {
            await PrintWithLibreOfficeAsync(filePath, printerName, timeout, cancellationToken);
            return;
        }

        if (extension is ".pdf" or ".png" or ".jpg" or ".jpeg" or ".tif" or ".tiff")
        {
            await PrintWithShellAsync(filePath, timeout, cancellationToken);
            return;
        }

        throw new NotSupportedException($"Unsupported file type: {extension}");
    }

    private static async Task PrintWithShellAsync(string filePath, TimeSpan timeout, CancellationToken cancellationToken)
    {
        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = filePath,
            Verb = "print",
            UseShellExecute = true,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        });

        if (process is null)
        {
            throw new InvalidOperationException("Shell print process could not be started");
        }

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(timeout);
        await process.WaitForExitAsync(timeoutSource.Token);
    }

    private static async Task PrintWithLibreOfficeAsync(string filePath, string printerName, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var candidates = new[]
        {
            @"C:\Program Files\LibreOffice\program\soffice.exe",
            @"C:\Program Files (x86)\LibreOffice\program\soffice.exe"
        };
        var soffice = candidates.FirstOrDefault(File.Exists);
        if (soffice is null)
        {
            throw new InvalidOperationException("LibreOffice was not found");
        }

        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = soffice,
            Arguments = $"--headless --pt \"{printerName}\" \"{filePath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        });

        if (process is null)
        {
            throw new InvalidOperationException("LibreOffice print process could not be started");
        }

        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(timeout);
        await process.WaitForExitAsync(timeoutSource.Token);

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"LibreOffice exited with code {process.ExitCode}");
        }
    }
}
```

- [ ] **Step 4: Add printer detector**

Create `Printing/PrinterDetector.cs`:

```csharp
using System.Drawing.Printing;

namespace AutoPrintWindows.Core.Printing;

public sealed record PrinterInfo(string Name, bool IsAvailable, string? Reason);

public sealed class PrinterDetector
{
    public IReadOnlyList<PrinterInfo> Printers()
    {
        return PrinterSettings.InstalledPrinters
            .Cast<string>()
            .Select(name => new PrinterInfo(name, true, null))
            .ToList();
    }

    public PrinterInfo Find(string name)
    {
        var found = PrinterSettings.InstalledPrinters.Cast<string>().Any(p => string.Equals(p, name, StringComparison.OrdinalIgnoreCase));
        return found
            ? new PrinterInfo(name, true, null)
            : new PrinterInfo(name, false, "Printer was not found");
    }
}
```

- [ ] **Step 5: Run Windows tests**

Run:

```powershell
dotnet test windows\AutoPrintWindows\AutoPrintWindows.sln
```

Expected: all tests pass.

- [ ] **Step 6: Commit Windows print infrastructure**

Run:

```powershell
git add windows\AutoPrintWindows
git commit -m "feat(windows): add print adapter and file movement"
```

Expected: commit succeeds.

## Task 9: Windows WPF UI And Tray Loop

**Files:**
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/Tray/TrayIconService.cs`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/Views/StatusView.xaml`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/Views/SettingsView.xaml`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/Views/LogsView.xaml`
- Create: `windows/AutoPrintWindows/src/AutoPrintWindows.App/Views/CapabilityView.xaml`
- Modify: `windows/AutoPrintWindows/src/AutoPrintWindows.App/MainWindow.xaml`

- [ ] **Step 1: Add main window tabs**

Update `MainWindow.xaml`:

```xml
<Window x:Class="AutoPrintWindows.App.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:views="clr-namespace:AutoPrintWindows.App.Views"
        Title="Auto Print" Height="520" Width="760">
    <TabControl>
        <TabItem Header="Status">
            <views:StatusView />
        </TabItem>
        <TabItem Header="Settings">
            <views:SettingsView />
        </TabItem>
        <TabItem Header="Logs">
            <views:LogsView />
        </TabItem>
        <TabItem Header="Capabilities">
            <views:CapabilityView />
        </TabItem>
    </TabControl>
</Window>
```

- [ ] **Step 2: Add compact first-version views**

Create each view with visible operational fields. Start with `StatusView.xaml`:

```xml
<UserControl x:Class="AutoPrintWindows.App.Views.StatusView"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <StackPanel Margin="16">
        <TextBlock Text="Running" FontSize="20" Margin="0 0 0 12" />
        <TextBlock Text="Printer: Not selected" />
        <TextBlock Text="Queue: 0" />
        <TextBlock Text="Last scan: Never" />
    </StackPanel>
</UserControl>
```

Create `SettingsView.xaml`:

```xml
<UserControl x:Class="AutoPrintWindows.App.Views.SettingsView"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <StackPanel Margin="16">
        <CheckBox Content="Automatic printing" IsChecked="True" Margin="0 0 0 12" />
        <TextBlock Text="Printer" />
        <TextBox Text="" Margin="0 4 0 12" />
        <TextBlock Text="Scan interval seconds" />
        <TextBox Text="30" Margin="0 4 0 12" />
        <TextBlock Text="Stable wait seconds" />
        <TextBox Text="10" Margin="0 4 0 12" />
        <TextBlock Text="Max retries" />
        <TextBox Text="3" Margin="0 4 0 12" />
    </StackPanel>
</UserControl>
```

Create `LogsView.xaml`:

```xml
<UserControl x:Class="AutoPrintWindows.App.Views.LogsView"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Grid Margin="16">
        <DataGrid AutoGenerateColumns="False">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Time" Binding="{Binding CompletedAt}" />
                <DataGridTextColumn Header="File" Binding="{Binding FileName}" />
                <DataGridTextColumn Header="Status" Binding="{Binding Status}" />
                <DataGridTextColumn Header="Printer" Binding="{Binding PrinterName}" />
            </DataGrid.Columns>
        </DataGrid>
    </Grid>
</UserControl>
```

Create `CapabilityView.xaml`:

```xml
<UserControl x:Class="AutoPrintWindows.App.Views.CapabilityView"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <StackPanel Margin="16">
        <TextBlock Text="Printer: select a printer to check" Margin="0 0 0 8" />
        <TextBlock Text="PDF: available through configured local print path" Margin="0 0 0 8" />
        <TextBlock Text="Images: available through native image print path" Margin="0 0 0 8" />
        <TextBlock Text="Office: requires Microsoft Office or LibreOffice" />
    </StackPanel>
</UserControl>
```

- [ ] **Step 3: Add tray service**

Create `Tray/TrayIconService.cs`:

```csharp
using System.Windows;
using Forms = System.Windows.Forms;

namespace AutoPrintWindows.App.Tray;

public sealed class TrayIconService : IDisposable
{
    private readonly Forms.NotifyIcon _notifyIcon;

    public TrayIconService(Window mainWindow)
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open Settings", null, (_, _) => mainWindow.Show());
        menu.Items.Add("Pause Printing");
        menu.Items.Add("Quit", null, (_, _) => Application.Current.Shutdown());

        _notifyIcon = new Forms.NotifyIcon
        {
            Text = "Auto Print",
            Visible = true,
            ContextMenuStrip = menu,
            Icon = System.Drawing.SystemIcons.Application
        };
    }

    public void Dispose()
    {
        _notifyIcon.Dispose();
    }
}
```

- [ ] **Step 4: Build WPF app**

Run on Windows:

```powershell
dotnet build windows\AutoPrintWindows\AutoPrintWindows.sln
```

Expected: build succeeds and the tray icon appears when the app runs.

- [ ] **Step 5: Commit Windows UI**

Run:

```powershell
git add windows\AutoPrintWindows
git commit -m "feat(windows): add tray UI"
```

Expected: commit succeeds.

## Task 10: End-To-End Manual Acceptance

**Files:**
- Modify: `shared/acceptance-fixtures/README.md`
- Create: `docs/manual-test-results.md`

- [ ] **Step 1: Test macOS with a local or virtual printer**

Run the macOS app, configure a watch folder and printer, and place the acceptance fixture files into the folder.

Expected:

- Files are submitted in creation-time order.
- Successful files move to `printed`.
- Failed files retry three times and move to `failed`.
- Logs contain the required fields.
- Pause and resume work from the menu bar.

- [ ] **Step 2: Test Windows with a local or virtual printer**

Run the Windows app, configure a watch folder and printer, and place the acceptance fixture files into the folder.

Expected:

- Files are submitted in creation-time order.
- Successful files move to `printed`.
- Failed files retry three times and move to `failed`.
- Logs contain the required fields.
- Pause and resume work from the tray.

- [ ] **Step 3: Record test results**

Create `docs/manual-test-results.md`:

```markdown
# Manual Test Results

Record one row per platform test run. Use `pass`, `fail`, or `not run` for each file type.

| Platform | Date | OS Version | Printer | PDF | Image | Word | Excel | PowerPoint | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| macOS | 2026-05-18 | not run | not run | not run | not run | not run | not run | not run | Awaiting macOS acceptance run. |
| Windows | 2026-05-18 | not run | not run | not run | not run | not run | not run | not run | Awaiting Windows acceptance run. |
```

- [ ] **Step 4: Commit manual verification notes**

Run:

```bash
git add docs/manual-test-results.md shared/acceptance-fixtures/README.md
git commit -m "test: record manual print acceptance results"
```

Expected: commit succeeds after both platform tests are recorded.

## Self-Review

Spec coverage:

- Native macOS and Windows apps are covered by Tasks 2, 5, 6, and 9.
- Shared config and queue states are covered by Task 1.
- Folder scanning, creation-time order, stability detection, retries, movement, and logging are covered by Tasks 3, 4, 7, and 8.
- Printer and file format support are covered by Tasks 4 and 8.
- Manual acceptance for PDF, images, Word, Excel, and PowerPoint is covered by Task 10.

Platform constraints:

- macOS tasks can be built and tested on a macOS machine with Xcode.
- Windows WPF tasks must be built and tested on a Windows machine with .NET 8 Desktop workload.
- Real print acceptance requires a local or virtual printer on each platform.
