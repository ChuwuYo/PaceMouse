# AGENTS.md — PaceMouse

## Project overview

macOS 菜单栏工具：对高回报率（>500 Hz）鼠标的 move / drag 事件进行节流，减轻系统卡顿。点击与滚动不进入节流路径。

**目标**：高回报率鼠标在 macOS 上移动时不引起系统卡顿。

**非目标**：
- 不针对特定鼠标品牌/协议（不做厂商 HID 私有命令）
- 不改变鼠标固件协商的 USB 回报率本身
- 不做鼠标加速曲线、按键映射、滚轮增强（那是 LinearMouse / Mac Mouse Fix 的领域）

### 第一性原理（改动事件路径前必读）

事件链路自下而上：

```
鼠标固件 → USB 中断(每秒 N 次) → IOKit/IOHIDFamily(内核) → WindowServer 事件分发 → 前台 App
```

- **USB 中断层**：回报率由设备固件与主机在枚举时协商，macOS 无 API 干预 → 不可控
- **内核 HID 层**：IOKit 驱动，用户态无法触碰 → 不可控
- **WindowServer 分发层**：高回报率下此层处理压力与卡顿强相关 → 用户态最早介入点：`CGEventTap` @ `.cghidEventTap`

推论：
1. 通用用户态手段：在 `.cghidEventTap` 拦截 motion 事件，用令牌桶按 `targetHz` 决定放行；放行时把累加 delta 写回**同一事件**的 delta 字段，无令牌则吞掉。禁止合成事件、禁止 repost、禁止回读光标位置。
2. USB 中断本身无法减少；有效性依赖真机验证。
3. 事件 tap 必须常驻 → 菜单栏应用（`LSUIElement`），可随时开关。
4. 修改事件流需要 Accessibility；权限绑定签名 → 必须使用固定签名身份，禁止日常使用裸 ad-hoc（cdhash 变化会导致 TCC 授权失效）。

## Architecture

```
┌─ L0 App Shell      main / AppDelegate / StatusItemController / SettingsWindowController / SystemSettings
│                    菜单栏 NSPopover（开关/频率/更新提示）、设置窗、智能模式、本地化；不实现节流算法
│                    UpdateController —— Sparkle（自动/手动检查；静默发现后 Popover 项+图标提示，安装需确认）
├─ L1 Control        SettingsStore（UserDefaults：enabled、targetHz、customTargetHz、usesCustomRate、autoMode、autoThreshold、
│                    menuBarIcon、showLiveStats、includePreReleaseUpdates、permission/shake/login prompt 标记）
│                    应用语言完全跟随 macOS 单 App 语言设置，支持 en / zh-Hans / zh-Hant / ja / ko / pt / es / de / fr / it，
│                    不在 UserDefaults 中维护独立语言偏好
│                    自动检查更新开关走 Sparkle `automaticallyChecksForUpdates`（默认开）
│                    预发布更新：`includePreReleaseUpdates`（默认开）→ Sparkle `allowedChannels(["pre-release"])`
├─ L2 Core           ThrottleCore —— 位移累加器与统计（纯逻辑，可单测）
│                    TapBridge —— CGEventTap 生命周期、令牌桶、bypass、峰值统计、超时自愈
│                    PointerTuner —— 节流期间指针加速置 0 / 恢复
│                    HidRateMonitor —— 设置页硬件回报率测量
│                    Permissions —— Accessibility 检测与引导
│                    UpdateChannel —— Sparkle 渠道集合（pre-release / stable）
├─ L3 Native         PaceMouseHID（C shim）+ 打包 / 签名 / Sparkle appcast 脚本
```

依赖：只允许上层依赖下层；`PaceMouseCore` 不依赖 App 层；UI 经 `SettingsStore` / `AppDelegate` 驱动 `TapBridge`。

更新渠道：`version.env` 的 `RELEASE_CHANNEL`（当前 `pre-release`）写入 appcast 的 `sparkle:channel`；空则发到 Sparkle 默认稳定渠道。正式 1.x 时清空该变量即可。

### 备选：虚拟 HID（未采用）

若 CGEventTap 在未来系统上不可用，可评估：seize 物理鼠标 + `IOHIDUserDevice` 按 `targetHz` 注入累加报告。代价更高（权限、描述符、entitlement），不是当前实现路径。

### 核心算法（L2 规约）

1. tap mask 只含 motion（`mouseMoved` / `*MouseDragged`）；点击 / 滚动 / 键盘不进回调。
2. motion：delta 全部 `ThrottleCore.store`；令牌桶容量 4，按 `targetHz` 补充。有令牌则 `drain` 累加 delta，写入放行事件自身的 `mouseEventDeltaX/Y`；无令牌则返回 `nil` 吞掉。输入 ≤ `targetHz` 时不应长期抑制（含系统批量派发抖动）；输入更高时长期平均输出等于 `targetHz`。禁止用纯到达时间相位判定。
3. **禁止**新建合成事件、禁止 repost、禁止建模/回读光标位置。
4. `tapDisabledByTimeout` / `tapDisabledByUserInput` → `CGEvent.tapEnable`；每秒 health check（`CFMachPortIsValid` + `tapIsEnabled`），失效则重建 tap。
5. tap 跑在专用 `EventThread` RunLoop；bypass 切换与 stop/start 必须 `ThrottleCore.reset()`。
6. 拖拽期间保持原始事件类型（不可把 dragged 降成 moved）。
7. 节流激活时 `PointerTuner` 经 `IOHIDServiceClientSetProperty` 将指针加速写 0，停用/退出时恢复。键为 `HIDPointerAccelerationType` 的**字符串值**（如 `HIDMouseAcceleration`）；`IOHIDEventSystemClient` 须常驻持有。写 0 时落 UserDefaults 脏标记与原值；启动 `recoverIfNeeded()`；定时 `reapplyIfActive()` 覆盖热插拔。

智能模式（App 层）：`autoMode` 独立于手动 `enabled` 开关；开启后 `TapBridge` 必须常驻并先以 bypass 直通监测。每个统计周期及阈值变化时，按 `TapBridge` 最近上报的 `peakHz` 与当前 `autoThreshold` 重新判断：仅当 `peakHz > autoThreshold` 时节流（`bypass = false`），等于或低于阈值立即 bypass 直通，不保留旧阈值下的节流状态。

## Setup & build

- 构建：`swift build`
- 测试：`swift test`
- 打包：`Scripts/package_app.sh`（`MENU_BAR_APP=1` → `LSUIElement`）
- DMG：`Scripts/make_dmg.sh`（需先打包）
- 开发运行：`Scripts/compile_and_run.sh`
- 固定签名身份（一次）：`Scripts/setup_dev_signing.sh`
- 同步 Reference 克隆：`Scripts/sync_references.sh`
- 图标：`swift Scripts/make_icon.swift` → `iconutil`；入库路径为 `Sources/PaceMouse/Resources/Icon.icns`
- PoC（历史验证，非产品路径）：`PoC/main.swift` 等

## Screenshots（README）

入库路径：`docs/screenshots/`（`menu-en.png` / `menu-zh.png` / `settings-en.png` / `settings-zh.png` / `icon.png`）。

**强制**：只截 `/Applications/PaceMouse.app`（CI / Sparkle 装上的固定签名包）。**禁止**为截图执行 `Scripts/package_app.sh` / `compile_and_run.sh` 或打开仓库里的 ad-hoc `PaceMouse.app`——会换 cdhash，搞乱 Accessibility TCC，用户要重授权限。

流程概要：
1. 确认跑的是 `/Applications` 里那份；版本号与当前 `version.env` 一致后再截。
2. 菜单：点菜单栏图标 → `screencapture -l <window_id>`（或系统截图）→ `menu-zh.png` / `menu-en.png`。
3. 设置：Popover 里打开 Settings → 在 macOS「语言与地区」中切换 PaceMouse 的单 App 语言并重启，中英文各截一窗 → `settings-zh.png` / `settings-en.png`；截完恢复系统默认语言。
4. 取 window id：`CGWindowListCopyWindowInfo`，owner 含 PaceMouse 且高度足够的那扇；保留窗口阴影（不要 `screencapture -o`）。
5. 截图前可设 `permissionPromptShown` / `shakePromptShown` / `loginPromptShown` 为 true，避免启动引导弹窗挡画面（UserDefaults 域 `com.chuwuyo.pacemouse`）。

## Testing

- 必跑：`swift test`（`ThrottleCore`：累加、drain、reset、统计）
- 改动 L2 行为时：对照上方算法规约做对抗审查；真机验证输入输出频率与点击延迟（点击不得进节流路径）
- 提交前：`swift build` 零错误零新增警告

## Code style

- Swift 6.2 + SwiftPM + AppKit；无 Xcode 工程；菜单栏不用 SwiftUI 生命周期
- 不写注释（自解释命名；算法以本文档为准）；小函数；单一职责
- 改动架构或算法规约时，先改本文档再改代码

## Security & permissions

- 需要 Accessibility；首次运行须引导授权
- 日常签名：`Scripts/setup_dev_signing.sh` 的固定自签名（钥匙串 `~/Library/Keychains/pacemouse-dev.keychain-db`）；禁止日常裸 ad-hoc
- `Scripts/package_app.sh` 默认不加 `--timestamp`；公证用 `SIGN_TIMESTAMP=1`
- 对外分发：Developer ID + notarization；不提交证书私钥或 API key
- 许可：GPL-3.0（见 `LICENSE`）

## CI & release

- `.github/workflows/ci-release.yml`：push/PR 跑验证；`main` 通过后签名并滚动更新固定 tag 名 `app-latest` 的 Release 资产（DMG 原子换名 + Sparkle `appcast.xml` / zip）；不 force 移动 git tag tip
- Secrets：`PACEMOUSE_DEV_CERT_P12_BASE64`、`PACEMOUSE_DEV_CERT_PASSWORD`、`PACEMOUSE_DEV_CERT_SHA256`、`SPARKLE_PRIVATE_KEY`（EdDSA 私钥整段文本，对应 `Secrets/sparkle_eddsa_private.pem`）
- 本地生成/查看公钥：`Scripts` 依赖 `swift package resolve` 后的 `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account pacemouse`
- 更新包：`Scripts/make_appcast.sh`（需先 `package_app.sh`；读 `RELEASE_CHANNEL` / `SPARKLE_CHANNEL`）
- 更新通道校验：`Scripts/verify_update_channel.sh`

## References

- `Reference/references.yaml`：参考项目地址与用途（跟踪入库）
- `Reference/<name>/`：浅克隆源码，目录整体在 `.gitignore`，不提交克隆内容
- 更新克隆：`Scripts/sync_references.sh`

## PR & commit

- 提交前 `swift build` 通过；有单测的改动须 `swift test` 通过
- 提交信息一句话说明行为变化

## Review gate

核心引擎（L2）或平台权限/签名相关改动交付前：

1. 逐行自审（正确性、线程模型、生命周期、失败路径、边界）
2. 至少一个独立审查 agent 对照本文档算法规约审查
3. 问题清零后再打包；用户实测只验证体验与真机假设，不替代读码审查
