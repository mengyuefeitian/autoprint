# Spec: AutoPrint 自动检查更新 + 一键更新

## Objective

AutoPrint 目前的分发方式是本地生成 DMG，手动发给用户安装，用户永远不知道有没有新版本，也没有办法自己升级。本次改动给 AutoPrint 加上和 [InceptLaunch](/Users/xiaoan/Documents/code/InceptLaunch) 完全一致的自动更新能力：

- 应用每天自动在后台检查一次是否有新版本。
- 菜单栏下拉菜单里有「检查更新…」，随时手动触发。
- 发现新版本后，弹出 Sparkle 标准的更新提示 UI，用户点一下就能下载、校验、安装并重启到新版本——不需要用户手动去下载 DMG、退出旧 app、拖进「应用程序」。

参考实现：`/Users/xiaoan/Documents/code/InceptLaunch`（同一作者的另一个 SwiftPM + AppKit menu bar 项目，已经跑通 Sparkle 2 + GitHub Pages/Releases 的完整链路）。本设计尽量复用它已验证过的模式，而不是重新发明。

## Tech Stack

- Sparkle 2.6+（`https://github.com/sparkle-project/Sparkle`），通过 SwiftPM 引入。
- 分发托管：GitHub Pages（appcast.xml）+ GitHub Releases（DMG 文件），复用 `mengyuefeitian/autoprint` 这个已公开的仓库，和 InceptLaunch 用同一套基础设施类型，但密钥、feed URL、release 完全独立。

## Current State vs. Target State

| | 现状 | 改动后 |
|---|---|---|
| 主 app 构建方式 | `build_and_run.sh` 直接 `swiftc $(find ... *.swift)`，完全不走 SwiftPM | 改成 `swift build`（SwiftPM 解析并构建 Sparkle 依赖），构建产物从 `.build` 拷进 app bundle |
| 依赖 | 无第三方依赖 | 新增 Sparkle |
| Info.plist | 无更新相关字段 | 新增 `SUFeedURL` / `SUPublicEDKey` / `SUEnableAutomaticChecks` / `SUScheduledCheckInterval` |
| 菜单栏 | 设置 / 查看日志 / 暂停打印 / 立即打印 / 退出 | 增加「检查更新…」 |
| 发布 | `release.sh` 只在本地生成 DMG，从不上传 | `release.sh` 不变；新增 `publish_release.sh` 负责签名 + 生成 appcast 片段；上传 GitHub Release + 更新 `docs/appcast.xml` 是独立、需要人工确认的一步 |

## Components

### 1. `Package.swift`

在现有 `AutoPrintMac` executable target 上加 Sparkle 依赖和 rpath，完全照抄 InceptLaunch 的写法：

```swift
let package = Package(
    name: "AutoPrintMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AutoPrintMac", targets: ["AutoPrintMac"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "AutoPrintMac",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "AutoPrintMac",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(name: "AutoPrintMacTests", dependencies: ["AutoPrintMac"], path: "AutoPrintMacTests")
    ]
)
```

### 2. `AutoPrintMac/Core/UpdateService.swift`（新文件）

直接照抄 InceptLaunch 的 `UpdateService.swift` 模式：

- `UpdaterConfigurable` 协议只暴露 `automaticallyChecksForUpdates` 和 `updateCheckInterval` 两个属性，`SPUUpdater` 实现它。这层抽象存在的唯一目的是让配置逻辑可以脱离真实 `SPUUpdater`（需要真实 app host + 网络）做单元测试。
- `UpdateService.desiredConfiguration`：`(automaticallyChecksForUpdates: true, updateCheckInterval: 86400)`，`nonisolated static let`，纯数据，可在任何上下文读取和测试。
- `UpdateService.configure(_:)`：把 `desiredConfiguration` 应用到任意 `UpdaterConfigurable`，纯函数，可测。
- `UpdateService` 实例持有一个 `SPUStandardUpdaterController`（`startingUpdater: true`），初始化时调用 `configure`。
- `checkForUpdates()`：转发给 `controller.checkForUpdates(nil)`，给菜单手动触发用。
- 下载/校验/安装/重启的所有 UI 都是 Sparkle 自带的标准弹窗，这一层不实现任何界面。

### 3. `MenuBarController.swift`

- 加一个 `checkForUpdatesMenuItem`，放在现有「立即打印」和分隔线之间（和暂停/立即打印同一组，「退出」前面用分隔线隔开，不变）。
- `applicationDidFinishLaunching` 里创建 `AutoPrintEngine.shared.start()` 之后，实例化 `let updateService = UpdateService()` 并持有为属性（避免被释放）。
- 点击菜单项调用 `updateService.checkForUpdates()`。
- `Localization.swift` 加 `L10nKey.checkForUpdates`（"检查更新…" / "Check for Updates…"）。

### 4. `Resources/Info.plist`

新增四个键（版本号相关键不变，仍由 `release.sh` 管理）：

```xml
<key>SUFeedURL</key>
<string>https://mengyuefeitian.github.io/autoprint/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>{AutoPrint 专用公钥，生成后填入}</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
```

### 5. 构建脚本改动：`script/build_and_run.sh`

这是本次改动里风险最高的一块，因为它把 AutoPrint 主 app 的构建方式从「裸 `swiftc` 编译文件列表」换成「`swift build`（SwiftPM）」。原因：Sparkle 是 SwiftPM 包，裸 `swiftc` 没有依赖解析能力，没法把它的源码/预编译产物找出来手动传给 `swiftc`（InceptLaunch 也是因为这个原因才用 `swift build`，而不是像 AutoPrint 原来那样手写文件列表）。

改动点：
1. 用 `swift build` 替换原来的 `swiftc $(find AutoPrintMac -name '*.swift' | sort)`，编译产物路径用 `swift build --show-bin-path` 取得。
2. 已验证过的本机工具链/SDK 兼容处理（[[autoprint-toolchain-sdk-mismatch]]：默认 SDK 编译不过 Combine、且不给 `-target` 会导致 minos 跑到编译器自己的默认版本）继续保留并同样套用到 `swift build` 调用上——`SDK_FLAGS`/`TARGET_FLAGS` 的探测逻辑不变，只是从传给 `swiftc` 改成通过 `SDKROOT` 环境变量 + 确认 `Package.swift` 里 `platforms: [.macOS(.v14)]` 已经声明了正确的部署目标（`swift build` 会读取 `Package.swift` 的 `platforms`，不需要再手动传 `-target`，但仍需要正确的 `SDKROOT` 让 Combine 能被解析到）。
3. 新增：把 `swift build` 产出目录下的 `Sparkle.framework`（`find .build -type d -name Sparkle.framework -path '*macos*'`）拷贝进 `$APP/Contents/Frameworks/`。
4. 构建后的 `minos` 校验逻辑（上次刚加的 otool 检查）保留，因为 `swift build` 路径下同样可能出现 deployment target 跑偏的问题，值得继续守着。
5. `codesign` 时机不变，但改成 `--deep`（因为现在 bundle 里多了一层 Sparkle.framework 及其内部的 XPC services / Updater.app，需要一并签到）。

### 6. 新增 `script/publish_release.sh`

照抄 InceptLaunch 版本，改成 AutoPrint 的路径/URL：

- 用法：`publish_release.sh <version> <dmg路径>`。
- 读 `SPARKLE_PRIVATE_KEY_FILE`（默认 `~/.config/autoprint/sparkle_signing_key`），用 Sparkle 自带的 `sign_update` 工具对 DMG 做 EdDSA 签名。
- 从已构建的 `dist/AutoPrint.app/Contents/Info.plist` 读 `LSMinimumSystemVersion`，不硬编码（避免把更新推给装不了的老系统）。
- 打印出一段 `<item>` XML（含 `sparkle:version`、`sparkle:shortVersionString`、`sparkle:minimumSystemVersion`、签名后的 `enclosure`），下载地址指向 `https://github.com/mengyuefeitian/autoprint/releases/download/v<version>/<dmg文件名>`。
- **不自动**粘贴进 `docs/appcast.xml`、不自动 `git push`、不自动上传 GitHub Release——这些是我在你确认后手动执行的步骤（对应你选的"打包后由我确认，再手动/半自动发布"）。

### 7. `docs/appcast.xml`（新文件，首次发布前创建）

InceptLaunch 同款 RSS + Sparkle 命名空间格式，`<channel><link>` 指向 `https://mengyuefeitian.github.io/autoprint/appcast.xml`。每次发布把 `publish_release.sh` 输出的 `<item>` 贴到 `<channel>` 最上面（最新的在最前）。

### 8. 签名密钥

- 用 Sparkle 自带的 `generate_keys` 工具（`swift build` 拉取 Sparkle 后能在 `.build/artifacts/sparkle/...` 下找到，和 `sign_update` 同目录）生成一套**AutoPrint 专用**的新 EdDSA 密钥对，和 InceptLaunch 的完全独立。
- 私钥用 `generate_keys -x ~/.config/autoprint/sparkle_signing_key` 导出成一个纯文件，**不进 git、不进 macOS Keychain**（和 InceptLaunch 的选择一致：私钥只活在这一台机器的一个 owner-only 文件里）。
- 公钥填进 `Info.plist` 的 `SUPublicEDKey`（这个是公开信息，可以进 git）。

## Testing

- `AutoPrintMacTests/UpdateServiceTests.swift`（XCTest，跟现有测试目标风格一致，不引入 Swift Testing 这第二套框架）：
  - `UpdateService.desiredConfiguration` 的两个值符合预期（每日一次、自动检查开启）。
  - 用一个实现 `UpdaterConfigurable` 的 fake 对象验证 `UpdateService.configure(_:)` 会把这两个值写进去——不接触真实 `SPUUpdater`。
- 不测试 Sparkle 本身的下载/校验/安装逻辑（那是 Sparkle 的职责，不是我们的代码）。
- 构建产物的 `Sparkle.framework` 是否正确嵌入、`codesign --verify --deep` 是否通过：作为 `build_and_run.sh` 的构建后校验步骤，跟现有 `minos` 校验一样是自动化的"守门"检查，不是人工肉眼测试。

## Rollout / First-Time Setup（这部分是一次性的，不是每次发布都要做）

1. 生成 AutoPrint 专用 Sparkle 密钥对，公钥填进 Info.plist。
2. 在 GitHub 仓库 `mengyuefeitian/autoprint` 的 Settings → Pages 里，把 Pages 源设成 `main` 分支的 `/docs` 目录（和 InceptLaunch 一样）。
3. 创建初始 `docs/appcast.xml`（channel 元信息 + 第一条 `<item>`，对应本次改动完成后打的那个版本）。
4. 手动把对应版本的 DMG 上传成一个 GitHub Release（`gh release create v<version> <dmg> ...`）。
5. 之后每次发布：`release.sh` 照旧打包 → `publish_release.sh` 签名生成 XML 片段 → 我告诉你"即将发布 vX.X.X 到 GitHub"，你确认后我执行上传 + 更新 appcast.xml + push。

## Boundaries

- **Always do**：每次改这块代码后跑 `UpdateServiceTests`；私钥只放本地文件，绝不提交、绝不打印到日志。
- **Ask first**：任何一次"上传 GitHub Release / push appcast.xml"（即真正对外发布新版本）之前，必须明确告诉你版本号并等你确认。
- **Never do**：把私钥、或任何签名后的中间产物提交进 git；跳过 `minos`/codesign 的构建后校验。

## Open Questions

无——三个关键决策点（托管方式、密钥独立生成、发布需人工确认）已经在对话中确认。
