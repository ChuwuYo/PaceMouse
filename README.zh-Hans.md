<p align="center">
  <img src="docs/screenshots/icon.png" width="128" alt="PaceMouse">
</p>

<h1 align="center">PaceMouse</h1>

<p align="center">
  <a href="README.md">English</a>
  &nbsp;·&nbsp;
  <strong>中文</strong>
</p>

macOS 菜单栏工具：对高回报率鼠标的 **移动 / 拖拽** 事件进行节流，减轻卡顿。

macOS 目前对高回报率（>500 Hz）支持不佳。若同一只鼠标在多台设备间切换（Windows / Linux / macOS），可用 PaceMouse 在事件进入系统分发前对移动 / 拖拽事件进行节流；点击与滚动不受影响。

## 安装

1. 从 [Releases](https://github.com/ChuwuYo/PaceMouse/releases) 下载 DMG 安装包
2. 打开后把 PaceMouse 拖进「应用程序」
3. 首次打开若被拦截：到 **系统设置 → 隐私与安全性** 点 **仍要打开**（或右键 App → 打开）
4. 按提示授予**辅助功能**权限

## 截图

<p align="center">
  <img src="docs/screenshots/menu-zh.png" width="280" alt="菜单栏菜单"><br>
  <img src="docs/screenshots/settings-zh.png" width="420" alt="设置">
</p>

## 使用

- 通过菜单栏图标开启或关闭节流
- 目标频率：**125 / 250 / 500 Hz**（默认建议 250）
- 可选**智能模式**：仅当实测输入超过阈值时启用节流
- 运行时可在菜单中查看 `输入 → 输出` Hz

PaceMouse **不会**修改 USB 回报率、加速曲线、按键或滚轮。此类需求可使用 [LinearMouse](https://github.com/linearmouse/linearmouse)、[Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) 等工具。

## 原理

macOS 没有用于降低设备协商 USB 回报率的公开 API。PaceMouse 在 `.cghidEventTap` 层通过 `CGEventTap` 累加移动增量，并按目标频率（令牌桶）放行；非移动事件不进入该路径。

## 参考

- [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) — 事件 tap 生命周期 / 权限
- [LinearMouse](https://github.com/linearmouse/linearmouse) — macOS 鼠标工具架构
- [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) — 高回报率下的事件处理
- [EventTapper](https://github.com/usagimaru/EventTapper) — CGEventTap 的小型 Swift 封装
- [pollingrate](https://github.com/84ix/pollingrate) — macOS 鼠标回报率测量
- [razer-mouse-lite-macos](https://github.com/NZKea/razer-mouse-lite-macos) — 菜单栏形态参考

## 许可

[GPL-3.0](LICENSE)
