# v0.6 验证记录 · 2026-10-27

## 本轮结果

- Mac 通用构建和临时签名验证通过，包含 arm64 与 x86_64。
- Mac 原生自检全部通过：中文分页、阅读锚点、草稿隔离、锁定恢复、Word 导入/保留版式、取消/超时、PDF 去白/原页/缓存、多屏边界、提词、页副本、设置读写。500 段分页约 0.060 秒，不是普遍性能保证。
- Windows 10 项 Node 自动测试通过：锁定、页码缩放边界、提词约束、DOCX、去白像素、屏幕恢复、顺序保存与清除。
- Chromium/Edge 浏览器桥接集成检查通过：文字分页、缩放、锁定、可控时钟下的倒计时/滚动/暂停、设置溢出布局、PDF.js 真正渲染与去白切换；没有渲染层异常。
- 浏览器测试模拟 IPC，不验证 Electron 系统窗口。常规点击/截图等待在本机浏览器环境超时，因此使用事件派发和可控时钟；不能据此宣称真实鼠标操作和视觉截图验收通过。
- Windows 转换模块在 Mac 上调用 LibreOffice：中文测试 DOCX 得到有效 PDF，预取消检查通过。首次转换触发 45 秒超时；复制到隔离目录后复测通过。Windows LibreOffice 仍需实测。
- Windows x64 使用先前已按官方摘要校验的 Electron 运行时跨平台打包；产物完整性另行检查。
- npm 安装审计报告 0 个已知漏洞，不等于安全审计。

## 尚未覆盖

Windows 原生运行、透明/穿透/托盘/跨应用热键、高 DPI、真实多屏拔插、Intel Mac、读屏、真实用户试用和长时间性能。见 [P2 验收清单](docs/P2_ACCEPTANCE.md)。

## 复现

```sh
bash scripts/build-app.sh
dist/GlassText.app/Contents/MacOS/GlassText --self-test
cd windows
npm ci
npm test
GLASSTEXT_BROWSER="/path/to/chromium-or-edge" npm run test:browser
npm run build
```

Mac 自检需要图形会话，使用独立设置域；浏览器测试使用合成文档和隔离浏览器，不读取真实文档。

---

以下为 v0.5 历史记录，不应理解为 v0.6 的 Windows 实机记录。

# v0.5 验证记录

## Mac

- release 编译成功，lipo 确认 arm64 与 x86_64 双架构，codesign 验证临时签名。
- 中文分页完整性、阅读位置保持、草稿隔离、锁定恢复、中文 DOCX、LibreOffice 转 PDF、取消、进程超时、空/损坏文件处理通过。
- PDF 去白像素/原页切换、窗口边界恢复、跳页、提词倒计时/滚动/暂停、页副本、设置读写通过。
- 缩放范围、锁定禁止翻页/缩放、取消禁止后可操作的检查通过。
- 四步引导截图生成、红框坐标和切换检查通过；第一步示例截图已目视核对，见 docs/images/onboarding.png。
- 500 段中文样例分页约 0.05–0.07 秒。不是大文档性能保证。

## Windows

- Node 语法检查通过。
- 5 项自动测试通过：独立锁定策略、恢复操作、页码/缩放边界、中文 DOCX 提取、缺失文档拒绝。
- npm 依赖安装时审计报告为 0 个已知漏洞；这不等于安全审计。
- 官方 Electron Windows x64 ZIP 已按 electron 包提供的 SHA-256 校验。
- 没有 Windows 真机运行记录；渲染、透明、拖放、热键、托盘和高 DPI 兼容性仍需验收。

## 未覆盖

跨应用热键真实触发、多屏拔插、Intel 真机、Windows 真机、复杂扫描 PDF、超长时间运行及辅助功能。Mac 的原生状态断言不能代替 Windows 的端到端验收。

复现命令：

```sh
bash scripts/build-app.sh
dist/GlassText.app/Contents/MacOS/GlassText --self-test
cd windows
npm ci
npm test
npm run build
```
