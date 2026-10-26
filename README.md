# 透明文字 · GlassText

原生 macOS 透明内容展示工具。需要 macOS 13 或以上，无第三方依赖，文件仅在本机处理。

## 使用

下载 Release 中的 `GlassText-macOS.zip`，解压后将 GlassText.app 拖到“应用程序”，双击启动。当前提供 Apple Silicon 版本；Intel Mac 可从源码本地构建。

应用使用本地临时签名，尚未经过 Apple 公证。首次启动可能需要在“系统设置 → 隐私与安全性”允许打开。

- 在控制面板输入文字，点击“放映输入的文字”。支持中文、字号与颜色调整、长文本自动分页。
- 打开 PDF、Word（doc/docx）、RTF、TXT 或 Markdown 文件。
- PDF 保留页面布局，并把白色转换为透明。白底图像也会参与处理；彩色纸张、扫描阴影不保证完全去除。PDF 使用原文颜色，字号与颜色控件仅影响文字模式。
- Word 转成纯文字分页，不保留插图、表格布局和原排版。需要保留布局时，请先从 Word 导出 PDF。
- 展示窗口无标题栏、无背景、无阴影，可置顶、跨桌面显示和鼠标穿透。控制面板可关闭，通过菜单栏“透 Aa”重新打开。
- 拖动内容移动窗口，拖动窗口边缘调整大小。“重置位置”可恢复默认尺寸与位置。
- ⌘O 打开文件，⌘0 打开控制面板，⌘I 切换鼠标穿透，⌘[ / ⌘] 翻页。这些快捷键在应用激活时生效；穿透时请使用菜单栏恢复。

## 构建

安装 Apple Command Line Tools 后运行：

```sh
bash scripts/build-app.sh
open dist/GlassText.app
```

产物：`dist/GlassText.app` 与 `dist/GlassText-macOS.zip`。使用 Swift / AppKit / PDFKit；Word 由 macOS 自带 textutil 转换。

## 验证

```sh
dist/GlassText.app/Contents/MacOS/GlassText --self-test
```

在图形登录会话中验证中文分页完整性、前后翻页、穿透状态、置顶级别及 PDF 白底透明化。需手动检查不同桌面背景、实际 Word 文档及全屏应用兼容性。置顶不覆盖系统安全界面。
