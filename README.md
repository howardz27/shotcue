# ShotCue

ShotCue 是一款给 AI Agent 提截图反馈的 macOS 原生工具。在图上标出要改的位置，写下「当前问题」和「期望调整」，再把带编号的图片或 Markdown 反馈贴给 Agent。

## 下载与安装

[下载 ShotCue（Apple Silicon）](https://github.com/howardz27/shotcue/releases/latest/download/ShotCue-macOS-arm64.zip)

1. 确认 Mac 使用 Apple Silicon 芯片，并运行 macOS 14 或更新版本。
2. 解压下载的 ZIP，把 `ShotCue.app` 拖到「应用程序」文件夹，再双击打开。

当前版本使用临时签名，尚未经过 Apple 公证。如果首次启动被 macOS 拦截，确认文件来自本仓库的 Release 后，可在「系统设置 → 隐私与安全性」中选择「仍要打开」。[Apple 的首次打开说明](https://support.apple.com/en-us/102445)

ShotCue 可离线使用，最近一次评审会作为草稿保存在本机。

## 评审截图

1. 把图片拖进窗口，使用「打开」选择文件，或者按 `⌘V` 粘贴剪贴板里的图片。按 `⌘⇧S` 截取屏幕区域。通过「截图」旁的下拉按钮选择是否隐藏 ShotCue 窗口，应用会记住此设置。
2. 默认使用框标注。按 `1` 加编号点、`2` 拖出区域、`3` 拖出箭头。添加标注后直接输入当前问题，按 Tab 前往期望调整。按 Esc 返回画布即可继续使用标注快捷键。
3. 按 `V` 切换到指针。点击选择标注，拖框多选，按 `Ctrl+A` 或 `⌘A` 全选。拖动任一已选标注可一起移动。拖动单选标注的控制点可调整区域或箭头。按住空格拖动画布，按 `0` 恢复适合窗口的缩放。
4. 工具栏的色点会展开颜色面板，可点击预设色，也可拖动选色或输入十六进制色值。默认使用 ShotCue 图标的蓝色，应用会记住你的选择。
5. 「预览」可以查看导出 PNG。「复制图片」将这张 PNG 放入剪贴板。有文字说明时，PNG 会附上反馈清单。所有说明都留空时，导出保留原图尺寸和图上的标记。「复制反馈」生成带原图像素坐标的 Markdown。「保存」可选择 PNG 或 Markdown 并指定保存位置。

| 操作 | 快捷键 |
| --- | --- |
| 打开图片 | `⌘O` |
| 粘贴图片，编辑文字时仍可用 | `⌘⌥V` |
| 区域截图 | `⌘⇧S` |
| 指针 | `V` |
| 全选标注 | `Ctrl+A` / `⌘A` |
| 预览 PNG | `⌘Y` |
| 复制图片 | `⌘⌥C` |
| 复制反馈 | `⌘⇧C` |
| 保存 PNG | `⌘S` |
| 撤销 / 重做 | `⌘Z` / `⌘⇧Z` |

截图使用 macOS 的区域选取。若系统要求授权，可以在「系统设置 → 隐私与安全性 → 屏幕录制」检查权限。

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
