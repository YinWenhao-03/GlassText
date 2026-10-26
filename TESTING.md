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
