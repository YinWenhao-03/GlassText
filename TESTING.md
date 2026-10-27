# 测试

## v0.6.1 图标回归

Mac Dock 图标解码后的像素与打包设计图平均通道差异为 0.036（0–255），图标资源和 ZIP 完整性检查通过；Mac 功能回归通过。

## v0.6 测试结果

| 测试范围 | 结果 |
|---|---|
| Mac 构建 | arm64 / x86_64 通用包，临时签名校验通过 |
| Mac 功能回归 | 中文分页、阅读位置、草稿隔离、锁定恢复、Word 导入、取消与超时、PDF 去白与缓存、提词、页副本和设置读写通过 |
| Windows 逻辑测试 | 10 项通过，覆盖锁定、缩放边界、提词约束、DOCX、去白像素、窗口范围、顺序保存与清除 |
| Windows 渲染测试 | 分页、缩放、锁定、提词、设置布局及 PDF.js 渲染通过 |
| Word 转换模块 | 在 macOS 上使用 LibreOffice 将中文 DOCX 转为 PDF；预取消检查通过 |
| 发行包 | ZIP 完整性、包内源码一致性、Windows 图标与版本资源检查通过 |

Windows 渲染测试在 Chromium/Edge 中运行，使用模拟 IPC、事件派发和可控时钟。测试数据为合成文字与 PDF。

Windows 系统级验收待执行：透明窗口、鼠标穿透、托盘、跨应用快捷键、高 DPI、多屏拔插和长期运行。Intel Mac、读屏软件和复杂扫描件也列入后续测试。

## 运行测试

```sh
# macOS
bash scripts/build-app.sh
dist/GlassText.app/Contents/MacOS/GlassText --self-test

# Windows 项目
cd windows
npm ci
npm test
GLASSTEXT_BROWSER="/path/to/chromium-or-edge" npm run test:browser
npm run build
```

Mac 自检需要图形会话，使用独立设置域。`GLASSTEXT_BROWSER` 指向本机安装的 Chromium 或 Edge 可执行文件。

## 性能样例

Mac 上 500 段中文样例分页耗时约 0.060 秒。大文档内存、导入进度及长时间运行测试计划见 [发布清单](docs/P2_ACCEPTANCE.md)。
