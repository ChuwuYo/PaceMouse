# AGENTS.md — PaceMouse

## Project overview

macOS 高回报率鼠标卡顿的通用解决方案。菜单栏常驻工具，在事件进入系统分发前按固定节奏节流重发。

**目标**：任意回报率（1000/2000/4000/8000Hz）的鼠标在 macOS 上移动时不引起系统卡顿（视频掉帧、UI 撕裂、WindowServer 高负载）。

**非目标**：
- 不针对特定鼠标品牌/协议（不做厂商 HID 私有命令）
- 不改变鼠标固件协商的 USB 回报率本身
- 不做鼠标加速曲线、按键映射、滚轮增强（那是 LinearMouse / Mac Mouse Fix 的领域）

### 第一性原理分析（架构公理，改动前必读）

事件链路自下而上：

```
鼠标固件 → USB 中断(每秒 N 次) → IOKit/IOHIDFamily(内核) → WindowServer 事件分发 → 前台 App
```

- **USB 中断层**：回报率由设备固件与主机在枚举时协商，macOS 无 API 干预 → 不可控
- **内核 HID 层**：IOKit 驱动，用户态无法触碰（DriverKit 需 Apple 专项授权且依然收全部中断）→ 不可控
- **WindowServer 分发层**：社区实测（sokol #1344、LinearMouse #1185）表明卡顿与高回报率下此层处理压力强相关 → 这是用户态最早的介入点：`CGEventTap` @ `.cghidEventTap`

推论：
1. 唯一通用的用户态手段 = 在 `.cghidEventTap` 吞掉 motion 事件，按固定节奏（如 250Hz）重发最新事件
2. 中断本身无法减少 → 方案有效性属经验假设，必须先以最小 PoC 验证；验证不过则项目终止，不进入正式开发
3. 事件 tap 必须常驻 → 形态为菜单栏应用（LSUIElement），可随时开关
4. 修改事件流需要 Accessibility 权限；权限绑定签名 → 必须使用固定签名身份，禁止临时 ad-hoc 签名导致授权失效

## Architecture（自上而下）

```
┌─ L0 App Shell      main.swift / AppDelegate / NSStatusItem（菜单栏图标、开关、频率选择）
│      只负责展示与用户意图，零业务逻辑
├─ L1 Control        SettingsStore（UserDefaults 持久化：enabled、targetHz）
│      状态的唯一来源，向下下发指令，向上暴露可观察状态
├─ L2 Core Engine    EventThrottler —— 节流算法（纯逻辑，不 import AppKit，可单测）
│                    TapBridge —— CGEventTap 生命周期（创建/回调/超时自愈/权限诊断）
├─ L3 Platform       Permissions（AX 权限检测与引导）、Signing、Packaging
```

依赖规则：只允许上层依赖下层；L2 不感知 L0/L1 的存在；UI 通过 L1 间接驱动引擎。

### 备选架构（虚拟 HID 路线，未采用）

若 CGEventTap 语义未来遇到无法解决的问题（如新版 macOS 改变 tap 行为、吞事件引发系统级副作用），终极方案是：

- `IOHIDDeviceOpen(kIOHIDOptionsTypeSeizeDevice)` 独占物理鼠标，直接读原始 HID 报告
- `IOHIDUserDeviceCreate` 创建虚拟鼠标（自写 report descriptor），以 targetHz 节奏向虚拟设备注入累加后的报告
- 系统把虚拟设备当真硬件：光标走原生引擎（原生加速/坐标），无 tap 语义坑

代价：seize 需要额外权限、报告描述符工程量大、IOHIDUserDevice 在新版 macOS 的可用性需先行 PoC 验证（可能需要 entitlement）。

**为何不是首选**：第一性原理要求先用最小代价验证核心假设——"在 WindowServer 前削减事件率能否消除卡顿"。CGEventTap 是用户态最早、成本最低的介入点，M0 当天即可验证假设；虚拟 HID 的工程量与未知性高出一个量级，假设不成立则全部浪费。假设已被真机验证成立后，CGEventTap 路线的语义问题已通过"抽取+相对注入"算法解决，虚拟 HID 仅作为兜底记录。

### 核心算法（L2 规约）

1. 回调中：tap mask 只含 motion 事件，其余事件根本不进入回调——点击/滚动/键盘零处理零延迟
2. motion 事件（`mouseMoved` / `*MouseDragged`）：全部进入累加器；采用**令牌桶**（容量 4，按 targetHz 速率补充）：有令牌则放行并将累加 delta 写入放行事件自身 delta 字段，无令牌则吞掉。性质：输入 ≤ targetHz 时零抑制（含系统批量派发造成的到达抖动）；输入 > targetHz 时长期平均输出精确等于 targetHz；禁止用纯到达时间相位判定（系统按显示刷新批量派发事件，到达时间不均匀，会少放一半以上）
3. **禁止**新建合成事件、禁止 repost、禁止建模/回读光标位置——合成事件的绝对定位语义与回读竞态是乱晃/漂移的根因（MMF `ModifiedDrag.m:288` 亦记录了吞事件重发导致光标跳动）
4. 收到 `tapDisabledByTimeout / tapDisabledByUserInput` 时自动 `CGEvent.tapEnable` 恢复；stats tick 每秒主动健康检查（`CFMachPortIsValid` + `tapIsEnabled`），失效立即重建
5. tap 运行在专用 EventThread RunLoop（不占用主线程，避免与被治理的卡顿争抢）；bypass 转换与 stop/start 必须 `core.reset()` 丢弃陈旧累加 delta
6. 拖拽期间事件类型必须与原始事件一致（dragged 不能被降级成 moved）
7. 节流激活期间通过 `IOHIDServiceClientSetProperty` 将指针加速写 0，停用/退出时恢复原值（PointerTuner）——否则累加后的大 delta 被系统加速曲线非线性放大，位移不守恒（闭环漂移）。目标键 = `HIDPointerAccelerationType` 的**字符串值**（如 `HIDMouseAcceleration`）；`IOHIDEventSystemClient` 必须常驻持有（释放后 service client 失效）；写 0 时在 UserDefaults 落脏标记与保存值，下次启动 `recoverIfNeeded()` 兜底崩溃/强杀场景；定时 `reapplyIfActive()` 覆盖热插拔；参考 MMF `PointerSpeed.m` 与 LinearMouse `PointerKit`

## Setup & build commands

- 构建：`swift build`
- 测试：`swift test`
- 打包：`Scripts/package_app.sh`（`MENU_BAR_APP=1` 注入 LSUIElement）
- 生成 DMG 安装包：`Scripts/make_dmg.sh`（需先打包）
- 开发运行：`Scripts/compile_and_run.sh`
- 一次性创建固定签名身份：`Scripts/setup_dev_signing.sh`
- 同步参考项目：`Scripts/sync_references.sh`
- PoC：`swiftc -O PoC/main.swift -o PoC/poc && swiftc -O PoC/generator.swift -o PoC/generator`

## Testing instructions（里程碑与验证门禁）

| 门禁 | 内容 | 通过标准 |
|---|---|---|
| M0 PoC | `PoC/main.swift`：验证 tap 创建、权限、吞并-重发链路 | 合成 1000Hz 事件流下 out≈targetHz±10%，无事件丢失导致的卡死，权限路径明确 |
| M1 核心引擎 | L2 按 Architecture 规约实现 + 算法单测 | 单测覆盖：节流率、magic 防循环、拖拽类型保持、透传零延迟 |
| M2 App 集成 | L0/L1 + 打包 + 固定签名 | 菜单栏可开关/调频，权限引导可用，重启后授权保持 |
| M3 实测调优 | 真机 1000~8000Hz 压测 | 见下方验收标准 |
| M4 发布（可选） | Developer ID + `Scripts/sign-and-notarize.sh` 公证 | `spctl --assess` 通过 |

**规则：前一门禁未过，不得开始下一门禁的工作。**

M3 验收标准：
- 输入 8000Hz 时输出频率 = targetHz ±5%，指针无可见跳变
- 点击事件端到端延迟与未开启时一致（不经过节流路径）
- 1000Hz 输入持续 10 分钟：本进程 CPU < 1%，内存无增长
- 主观验证：播放视频时快速晃动鼠标，不再掉帧
- WindowServer CPU 占用开启前后对比有显著下降

## Code style

- Swift 6.2 + SwiftPM executable + AppKit；无 Xcode 工程文件；不引入 SwiftUI 生命周期（菜单栏工具用 NSStatusItem 最直接）
- 不写注释（自解释命名；算法规约以本文档为准）；小函数；单一职责
- 改动架构先改本文档 Architecture 一节

## Security & permissions

- 运行需要 Accessibility 权限（修改事件流）；首次运行必须引导用户授权
- 签名使用 `Scripts/setup_dev_signing.sh` 创建的固定自签名证书（独立钥匙串 `~/Library/Keychains/pacemouse-dev.keychain-db`，免交互 codesign）；禁止裸 ad-hoc 作为日常使用签名（每次重编译 cdhash 变化会导致 TCC 授权失效）
- `Scripts/package_app.sh` 默认不加 `--timestamp`（避免超时服务器网络依赖）；公证构建用 `SIGN_TIMESTAMP=1`
- 不分发则不公证；对外分发走 Developer ID + notarization
- 不提交任何证书私钥、API key 到仓库

## CI & release

- `.github/workflows/ci-release.yml`：所有 push/PR 过统一验证关（零警告门禁 + `swift test` + 打包结构校验）；main 通过后才签名并滚动发布 `app-latest` Release（暂存资产→原子换名→可回滚→移 tag→终态核验）
- CI 签名 Secrets（仓库 Settings → Secrets）：
  - `PACEMOUSE_DEV_CERT_P12_BASE64`：`security export -k ~/Library/Keychains/pacemouse-dev.keychain-db -t identities -f pkcs12 -P <密码>` 后 base64
  - `PACEMOUSE_DEV_CERT_PASSWORD`：上述 p12 导出密码
  - `PACEMOUSE_DEV_CERT_SHA256`：`security find-certificate -c 'PaceMouse Development' -Z` 的 SHA-256（去空格）

## References

- `Reference/` 存放参考开源项目（浅克隆），不纳入 Git 跟踪（见 `.gitignore`）
- `references.yaml` 记录所有参考项目的地址、路径与用途
- 同步全部参考项目：`Scripts/sync_references.sh`

## PR & commit instructions

- 提交前必须 `swift build` 零错误零新增警告；有单测的改动必须 `swift test` 通过
- 提交信息：一句话说明行为变化，不堆叠细节

## Review gate（强制）

- 任何核心引擎（L2/L3）改动或里程碑交付前，**必须先通过子智能体对抗审查**，不得直接交给用户测试：
  - 逐行自审改动（正确性、竞态与线程模型、资源生命周期、失败路径、边界条件）
  - 召唤至少一个独立审查 agent 做对抗审查（对照 AGENTS.md 算法规约与 Reference 项目实践）
  - 审查发现的问题清零后才允许打包交付
- "用户实测"只用于验证体验与真机假设，不用于发现本可通过读码发现的缺陷
