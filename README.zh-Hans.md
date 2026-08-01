<p align="center">
  <img src="docs/screenshots/icon.png" width="128" alt="PaceMouse">
</p>

<h1 align="center">PaceMouse</h1>

<p align="center">
  <a href="README.md">English</a>
  &nbsp;·&nbsp;
  <strong>中文</strong>
</p>

<p align="center">
  <a href="https://github.com/ChuwuYo/PaceMouse/releases/tag/app-latest"><img src="https://img.shields.io/github/v/release/ChuwuYo/PaceMouse?display_name=release&include_prereleases&label=release" alt="release"></a>
  <img src="https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&logoColor=white" alt="macOS 14.0+">
</p>

macOS 菜单栏工具：对高回报率鼠标的 **移动 / 拖拽** 事件进行节流，减轻卡顿。

macOS 目前对高回报率（>500 Hz）支持不佳。若同一只鼠标在多台设备间切换（Windows / Linux / macOS），可用 PaceMouse 在事件进入系统分发前对移动 / 拖拽事件进行节流；点击与滚动不受影响。

## 安装

1. 从 [Releases](https://github.com/ChuwuYo/PaceMouse/releases) 下载 DMG
2. 打开后将 PaceMouse 拖入「应用程序」
3. 若首次打开被拦截：到 **系统设置 → 隐私与安全性** 选择 **仍要打开**（或右键 App → 打开）
4. 按提示授予**辅助功能**权限

## 截图

<p align="center">
  <img src="docs/screenshots/menu-zh.png" width="280" alt="菜单"><br>
  <em>菜单</em>
</p>

<p align="center">
  <img src="docs/screenshots/settings-zh.png" width="420" alt="设置"><br>
  <em>设置</em>
</p>

## 使用

- 通过菜单栏图标开启或关闭节流
- 目标频率：**125 / 250 / 500 Hz**（默认建议 250），也可自定义 **100–500 Hz** 整数
- 可选**智能模式**：仅当实测输入超过阈值时启用节流
- 运行时可在菜单中查看实时 `输入 → 输出` Hz
- 界面语言：英语、简体中文、繁体中文、日语、韩语、德语、法语、西班牙语、葡萄牙语、意大利语 — 在 **系统设置 → 通用 → 语言与地区 → 应用程序** 中为 PaceMouse 单独指定

PaceMouse **不会**修改 USB 回报率、加速曲线、按键或滚轮。如需这些功能，可使用 [LinearMouse](https://github.com/linearmouse/linearmouse)、[Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) 等工具。

## 原理

macOS 没有公开 API 可降低设备协商的 USB 回报率。PaceMouse 在 `.cghidEventTap` 用 `CGEventTap` 累加移动增量，再按目标频率（令牌桶）放行；非移动事件不走该路径。

## 参考

- [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) — 事件 tap 生命周期与权限
- [LinearMouse](https://github.com/linearmouse/linearmouse) — macOS 鼠标工具架构
- [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) — 高回报率下的事件处理
- [EventTapper](https://github.com/usagimaru/EventTapper) — 小型 Swift `CGEventTap` 封装
- [pollingrate](https://github.com/84ix/pollingrate) — 在 macOS 上测量鼠标回报率

## 许可

[GPL-3.0](LICENSE)
