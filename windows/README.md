# Windows 预览版

Electron 45 + PDF.js + Mammoth。目标 Windows 10/11 x64。源码与便携构建流程已提供，尚未 Windows 真机验收。

支持文字、UTF-8 TXT/Markdown、PDF 自动去白底、DOCX 纯文字读取、置顶/穿透、分页、50%–300% 缩放、PDF 平移、分别锁定翻页与缩放、托盘恢复和 Ctrl+Alt+G。

Mac 的提词、Word 保留版式、多页副本、完整阅读位置记忆尚未同步。当前关闭面板会最小化到托盘，点击“退出”结束应用。

```sh
npm ci
npm test
npm start
npm run build
```

便携 ZIP 必须整体解压再运行 GlassText.exe。未签名。应用内使用生图图标；Windows exe 的资源图标尚未定制（构建禁用平台签名/资源编辑）。

安全边界：渲染层禁止 Node 集成，启用 contextIsolation 和 sandbox，拒绝新窗口/页面导航与权限请求；IPC 按发送窗口校验。文件仅本机解析，读取上限 50 MB。图文引导截图仅在内存中使用。
