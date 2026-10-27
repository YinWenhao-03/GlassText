# Windows v0.6 预览版

Electron 45 + PDF.js + Mammoth。目标 Windows 10/11 x64。已跨平台打包，尚未 Windows 真机验收。

## 已实现

- 文字、UTF-8 TXT/Markdown、PDF、DOCX 纯文字。
- 安装 LibreOffice 后可将 DOC / DOCX / RTF 转 PDF 保留版式；独立临时目录、取消、45 秒超时、失败保留原内容。
- 透明、置顶、鼠标穿透、分页、50%–300% 缩放、PDF 平移、独立锁定翻页/缩放。
- PDF 去白开关与强度，文字颜色、粗细、对齐、行距、描边、不透明度和可选阅读底色。
- 连续提词、3 秒倒计时、速度、暂停和重置；锁定翻页时暂停，隐藏时停止。
- 阅读内容副本、页码、提词位置、PDF 平移、窗口位置和样式保存在本机；启动时恢复为可调整状态。
- 显示器选择、移除后的窗口恢复、最多 8 个固定画面；固定画面随主窗口锁定/显示，右键关闭。
- 恢复快捷键录入、占用检测、托盘恢复、清除阅读记录、截图编号红框引导。

## 构建

```sh
npm ci
npm test
npm start
npm run build
```

可选浏览器回归（通过模拟应用桥接测试共享渲染逻辑，不代替 Electron 实机测试）：

```sh
# 将 GLASSTEXT_BROWSER 指向已安装 Chromium/Edge 的可执行文件。
GLASSTEXT_BROWSER="/path/to/browser" npm run test:browser
```

测试使用隔离浏览器、合成文字/PDF、可控时钟，不读取用户文档。

## 发行与边界

便携 ZIP 必须整体解压再运行 GlassText.exe。当前不做代码签名；图标和版本资源在构建时写入 exe。

关闭控制面板会隐藏到托盘；用“退出”结束应用。文字、PDF 副本和位置存于 Electron userData 目录中的 document.json/session.json，未加密；设置里的“清除阅读记录”替换保存内容并重置位置，不是磁盘安全擦除。截图引导只在内存中使用。

渲染层禁止 Node 集成，启用 contextIsolation 和 sandbox，拒绝新窗口/导航及权限请求；IPC 校验发送窗口。导入上限 50 MB。普通文件解析取消会丢弃迟到结果；Word 转换会请求终止转换进程。

尚未完成：Windows 真机透明/高 DPI/全局键/多屏/托盘/长期运行验收；签名；自动更新安装器；多独立文档工作区。固定画面是静态副本，不能独立翻页。
