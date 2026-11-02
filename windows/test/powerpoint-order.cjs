// Optional Windows desktop check. Creates and closes only its own temporary deck.
const { _electron } = require('playwright-core');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { execFile } = require('node:child_process');
const run = require('node:util').promisify(execFile);

(async () => {
  const root = process.env.GLASSTEXT_APP_ROOT || path.resolve(__dirname, '..');
  const data = await fs.mkdtemp(path.join(os.tmpdir(), 'glasstext-ppt-'));
  const entry = path.join(data, 'main.cjs');
  await fs.writeFile(entry, `require('electron').app.setPath('userData',${JSON.stringify(data)});require(${JSON.stringify(path.join(root,'main.cjs'))});`);
  const app = await _electron.launch({executablePath:require('electron'),args:[entry]});
  try {
    await app.firstWindow();
    let panel;
    for(let i=0;i<100&&!panel;i++){
      panel=app.windows().find(w=>w.url().endsWith('/control.html'));
      if(!panel)await new Promise(resolve=>setTimeout(resolve,50));
    }
    await panel.evaluate(()=>window.glass.action('locked',true));
    const handles=await app.evaluate(({BrowserWindow})=>{
      const handle=file=>BrowserWindow.getAllWindows().find(w=>w.webContents.getURL().endsWith(file)).getNativeWindowHandle().readBigUInt64LE().toString();
      return [handle('/overlay.html'),handle('/unlock.html')];
    });
    const {stdout}=await run('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'powerpoint-order.ps1'),...handles],{timeout:60000});
    console.log(stdout.trim());
  }finally{await app.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
