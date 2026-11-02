// A slide show can enter the topmost band after the reader is already visible.
// Compare native z-order and only move reader windows actually covered by it.
const koffi = require('koffi');
const path = require('node:path');
const user = koffi.load('user32.dll');
const kernel = koffi.load('kernel32.dll');
const foreground = user.func('uintptr_t GetForegroundWindow()');
const top = user.func('uintptr_t GetTopWindow(uintptr_t)');
const next = user.func('uintptr_t GetWindow(uintptr_t, uint32_t)');
const visible = user.func('int IsWindowVisible(uintptr_t)');
const processId = user.func('uint32_t GetWindowThreadProcessId(uintptr_t, void *)');
const className = user.func('int GetClassNameW(uintptr_t, void *, int)');
const rect = user.func('int GetWindowRect(uintptr_t, void *)');
const monitor = user.func('uintptr_t MonitorFromWindow(uintptr_t, uint32_t)');
const monitorInfo = user.func('int GetMonitorInfoW(uintptr_t, void *)');
const position = user.func('int SetWindowPos(uintptr_t, intptr_t, int, int, int, int, uint32_t)');
const openProcess = kernel.func('uintptr_t OpenProcess(uint32_t, int, uint32_t)');
const queryImage = kernel.func('int QueryFullProcessImageNameW(uintptr_t, uint32_t, void *, void *)');
const closeHandle = kernel.func('int CloseHandle(uintptr_t)');

const pidBuffer = Buffer.alloc(4);
function pidOf(hwnd) {
  return processId(hwnd, pidBuffer) ? pidBuffer.readUInt32LE() : 0;
}
let lastPid, presentationApp;
function isPresentationApp(pid) {
  if (pid === lastPid) return presentationApp;
  lastPid = pid;
  presentationApp = false;
  const handle = openProcess(0x1000, 0, pid); // PROCESS_QUERY_LIMITED_INFORMATION
  if (!handle) return false;
  try {
    const name = Buffer.alloc(2048), length = Buffer.alloc(4);
    length.writeUInt32LE(name.length / 2);
    if (queryImage(handle, 0, name, length)) {
      const executable = path.win32.basename(name.toString('utf16le', 0, length.readUInt32LE() * 2));
      presentationApp = /^(powerpnt|wpp|wps)\.exe$/i.test(executable);
    }
  } finally { closeHandle(handle); }
  return presentationApp;
}
function bounds(hwnd) {
  const buffer = Buffer.alloc(16);
  return rect(hwnd, buffer) ? [0,4,8,12].map(offset => buffer.readInt32LE(offset)) : null;
}
function slideBounds(hwnd) {
  const box = bounds(hwnd);
  if (!box) return null;
  const name = Buffer.alloc(256);
  const count = className(hwnd, name, name.length / 2);
  if (name.toString('utf16le', 0, count * 2).toLowerCase() === 'screenclass') return box;
  const info = Buffer.alloc(40);
  info.writeUInt32LE(info.length);
  if (!monitorInfo(monitor(hwnd, 2), info)) return null;
  const full = [4,8,12,16].map(offset => info.readInt32LE(offset));
  return box.every((edge, i) => Math.abs(edge - full[i]) <= 2) ? box : null;
}
function overlaps(a, b) {
  return a && a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3];
}
function restoreAboveShow(windows) {
  const pid = pidOf(foreground());
  if (!pid || pid === process.pid || !isPresentationApp(pid)) return;
  const readers = windows.filter(w => w && !w.isDestroyed() && w.isVisible() && !w.isMinimized())
    .map(w => Number(w.getNativeWindowHandle().readBigUInt64LE()));
  const remaining = new Set(readers), covered = new Set(), slides = [];
  // Other processes can reorder or destroy windows while we walk the list.
  const seen = new Set();
  for (let hwnd = top(0); hwnd && remaining.size && !seen.has(hwnd); hwnd = next(hwnd, 2)) {
    seen.add(hwnd);
    if (remaining.delete(hwnd)) {
      const box = bounds(hwnd);
      if (slides.some(slide => overlaps(box, slide))) covered.add(hwnd);
    } else if (pidOf(hwnd) === pid && visible(hwnd)) {
      const box = slideBounds(hwnd);
      if (box) slides.push(box);
    }
  }
  // HWND_TOPMOST, NOSIZE | NOMOVE | NOACTIVATE | NOOWNERZORDER.
  for (const hwnd of readers) {
    if (covered.has(hwnd)) position(hwnd, -1, 0, 0, 0, 0, 0x53);
  }
}
module.exports = {restoreAboveShow};
