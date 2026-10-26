<div align="center">
  <img src="Assets/AppIcon-Glass.png" width="112" alt="GlassText 图标">
  <h1>GlassText · 透明文字</h1>
  <p>把资料放在手边，让文字浮在正在使用的应用上方。</p>
  <p><a href="https://github.com/YinWenhao-03/GlassText/releases">下载预览版</a> · <a href="docs/USER_GUIDE.md">使用指南</a> · <a href="docs/PRODUCT_REVIEW.md">产品迭代记录</a> · <a href="TESTING.md">验证范围</a></p>
</div>

GlassText 是一款桌面悬浮阅读工具。你可以打开文字、PDF 或 Word，把内容放在合适的位置，锁定后继续操作下面的应用。适合边操作边看资料、对照笔记和演讲提词。

**当前为 v0.5 预览版，不代表已完成全部 P2 发行验收。** Mac 使用原生 AppKit/PDFKit；Windows 为 Electron 首个预览实现，两端功能范围见下表。

## 看一眼就能上手

![截图红框新手引导](docs/images/onboarding.png)

主界面把常用操作分开，复杂设置默认收起。Mac 引导提供四步真实界面截图、红框和编号说明；截图只在内存中生成，不上传文档内容。

1. **放入内容**：打开文件或拖入文档，也可以直接输入文字。
2. **调整阅读**：选择字号和颜色，移动窗口；用 `− / ＋` 调整 50%–300% 缩放。
3. **锁定展示**：窗口背景透明，鼠标穿透，继续操作下面的应用。
4. **恢复操作**：点击“返回调整”，或使用菜单栏 / 托盘与全局快捷键。

## 核心功能

- 透明展示、窗口置顶、鼠标穿透，控制面板独立存在。
- PDF 去白底并保留版式；纯文字分页、字号、颜色和描边。
- 页面放大、缩小和重置；PDF 放大后可以平移查看边缘内容。
- **锁定时是否禁止翻页、是否禁止缩放，可分别选择。** 默认两项均不禁止，仍可通过控制面板操作；展示窗口始终鼠标穿透。
- 导入失败保留原内容，避免正在阅读的资料消失。
- 文件在本机处理，没有文档上传服务。

## Mac / Windows 功能范围

| 功能 | macOS | Windows 首个预览版 |
|---|---|---|
| 文字 / TXT / Markdown | 支持 | 支持 UTF-8 文本 |
| PDF | 去白开关、强度、缩放、平移 | 自动去白、缩放、平移 |
| Word | DOC / DOCX / RTF 提取文字；可选 LibreOffice 转 PDF 保留版式 | DOCX 提取文字；DOC 和保留版式请先转 PDF |
| 置顶 / 穿透 / 独立锁定选项 | 支持 | 支持 |
| 提词滚动 / 倒计时 / 暂停 | 支持 | 尚未同步 |
| 外观与位置、阅读进度记忆 | 支持 | 保存基本外观和锁定选项，不保存文档及阅读位置 |
| 多屏与副本 | 显示器切换、越界恢复、最多八个当前页副本 | 显示器移除后的窗口恢复，单展示窗口 |
| 恢复快捷键 | 默认 `⌃⌥⌘G`，设置可选 G/T/R | `Ctrl+Alt+G` |
| 图文引导 | 四步截图＋编号红框 | 四步面板截图＋红框说明 |
| 发布验证 | 本机编译、自动检查与部分视觉检查 | 跨平台打包和逻辑测试；尚未 Windows 真机验收 |

## 下载与安装

从 [Releases](https://github.com/YinWenhao-03/GlassText/releases) 选择对应附件。私有仓库需要登录具有访问权限的 GitHub 账号。

- **Mac**：下载 `GlassText-macOS.zip`，解压后将 `GlassText.app` 拖入“应用程序”。macOS 13+，包含 Apple Silicon 和 Intel 两种架构。更新前退出旧版本。
- **Windows**：下载 `GlassText-Windows-0.5.0-x64.zip`，完整解压文件夹后运行其中的 `GlassText.exe`，不要只复制 exe。目标为 Windows 10/11 x64；尚未真机验证。
- 下载页同时提供 SHA-256 校验文件。

应用尚未取得 Apple 公证或 Windows 代码签名。Mac 首次打开可能需要在系统“隐私与安全性”允许打开；Windows 可能出现未识别应用提示。不要将这些预览包当作经过正式签名的稳定版本。

## 构建与测试

### macOS

安装 Apple Command Line Tools 后，在项目根目录执行：

```sh
bash scripts/build-app.sh
dist/GlassText.app/Contents/MacOS/GlassText --self-test
open dist/GlassText.app
```

构建产物在 `dist/`。测试需要图形登录会话，会短暂打开窗口，使用独立设置域。

### Windows

在 Windows x64 安装 Node.js 22（22.13+）后：

```sh
cd windows
npm ci
npm test
npm start
npm run build
```

依赖已锁定在 `package-lock.json`。GitHub Actions 配置示例见 [windows-workflow.example.yml](windows/ci/windows-workflow.example.yml)。当前凭据缺少 workflow 权限，尚未启用；有相应权限后将其放入 `.github/workflows/windows.yml`。

## 限制与隐私

- 去白底会影响图片中的白色；扫描阴影、彩色纸张和 OCR 识别不在保证范围内。
- Mac Word 保留版式模式依赖 `/Applications/LibreOffice.app`，复杂公式、字体和排版仍可能与 Word 不同。
- 置顶不保证覆盖系统安全界面或所有全屏应用。全局快捷键可能被其他应用占用，菜单栏 / 托盘保留恢复入口。
- Mac 本地设置会保存输入文字、最近文件路径、样式和阅读进度；Windows 仅保存基本设置。两端都不上传文档。图文引导的当前内容截图仅保留在内存。
- “查看更新”是手动访问 GitHub 发布页，并非自动更新安装器。
- 当前多窗口是当前页副本，不是多文档编辑器。

## 项目结构

```text
Sources/GlassText/     原生 Mac 应用、导入、引导与自动检查
windows/              Windows Electron 应用与测试
scripts/              通用 Mac 构建、可选签名与公证流程
Assets/               生图生成的玻璃图标及 macOS 图标资源
docs/                 用户指南、产品走查与截图
windows/ci/           Windows 自动构建配置示例（未启用）
```

后续工作见 [ROADMAP.md](ROADMAP.md)，验证记录见 [TESTING.md](TESTING.md)。正式签名、公证和完整实机验收仍需完成。
