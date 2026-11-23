<p align="center">
  <img src="docs/media/shotcue-logo.png" width="96" alt="ShotCue Logo">
</p>
<h1 align="center">ShotCue</h1>
<p align="center">给 AI Agent 的截图反馈工具</p>

在图上圈出要改的位置，写下「当前问题」和「期望调整」，再把带编号的图片或 Markdown 反馈贴给 Agent。

![ShotCue 主界面，左侧是带编号标注的截图，右侧是对应的反馈清单](docs/media/workspace.png)

## 下载与安装

[下载 ShotCue](https://github.com/howardz27/shotcue/releases/latest/download/ShotCue-macOS-arm64.zip)

当前下载包适用于 Apple Silicon Mac，要求 macOS 14 或更新版本。解压 ZIP 后，把 `ShotCue.app` 拖到「应用程序」文件夹，再双击打开。

当前版本使用临时签名，尚未经过 Apple 公证。如果首次启动被 macOS 拦截，确认文件来自本仓库的 Release 后，可在「系统设置 → 隐私与安全性」中选择「仍要打开」。[Apple 的首次打开说明](https://support.apple.com/en-us/102445)

首次使用截图功能时，可在「系统设置 → 隐私与安全性 → 屏幕录制」中授权。

## 功能介绍

- **导入和截图**。打开文件、拖入或粘贴图片，也可以直接截取屏幕区域。截图时可选择是否隐藏 ShotCue 窗口，应用会记住设置。
- **编号标注**。用框、点或箭头定位问题。添加标注后可直接输入当前问题，按 Tab 前往期望调整，按 Esc 回到画布。
- **选择和调整**。指针支持点击、拖框多选和全选，可整组移动标注。拖动单选标注的控制点可以调整范围或方向。
- **自定义颜色**。工具栏的色点可展开下拉面板，支持预设色、拖动取色和十六进制色值。
- **交给 Agent**。预览、复制或保存带编号的 PNG，也可以复制带原图像素坐标的 Markdown。有文字时，PNG 会附上反馈清单。所有说明都留空时，导出保留原图尺寸和图上的标记。

ShotCue 可离线使用，最近一次评审会作为草稿保存在本机。

### 操作演示

![实际操作演示，拖框标注按钮，填写问题和期望调整，再查看导出预览](docs/media/shotcue-demo.gif)

### 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开图片 | `⌘O` |
| 粘贴图片，编辑文字时仍可用 | `⌘⌥V` |
| 区域截图 | `⌘⇧S` |
| 点、框、箭头 | `1` / `2` / `3` |
| 指针 | `V` |
| 全选标注 | `Ctrl+A` / `⌘A` |
| 平移画布 / 适合窗口 | 按住空格拖动 / `0` |
| 预览 PNG | `⌘Y` |
| 复制图片 | `⌘⌥C` |
| 复制反馈 | `⌘⇧C` |
| 保存 PNG | `⌘S` |
| 撤销 / 重做 | `⌘Z` / `⌘⇧Z` |

## 本地构建

需要 Swift 5.9 或更新版本，以及 Xcode 或 Command Line Tools。

```sh
./scripts/build-app.sh
open dist/ShotCue.app
```

验证图片导出、剪贴板、草稿恢复和撤销重做时，应用可把测试产物输出到临时目录。

```sh
"dist/ShotCue.app/Contents/MacOS/FrameNote" --self-test "$(mktemp -d)"
```

## 许可证

ShotCue 采用 [MIT 许可证](LICENSE)。
