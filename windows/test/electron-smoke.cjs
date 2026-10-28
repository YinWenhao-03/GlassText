// Real Electron windows and IPC. Does not certify OS mouse hit-testing or physical multi-monitor behavior.
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const {_electron}=require('playwright-core');
(async()=>{
 const sourceRoot=path.resolve(__dirname,'..'),root=process.env.GLASSTEXT_APP_ROOT||sourceRoot,out=path.resolve(sourceRoot,'../.work/windows-validation');await fs.mkdir(out,{recursive:true});
 const data=await fs.mkdtemp(path.join(os.tmpdir(),'glasstext-validation-'));
 const wrapper=path.join(data,'main.cjs');
 await fs.writeFile(wrapper,`const {app,Tray,BrowserWindow}=require('electron');app.setPath('userData',${JSON.stringify(data)});globalThis.trays=[];const original=Tray.prototype.setContextMenu;Tray.prototype.setContextMenu=function(menu){globalThis.trays.push({tray:this,menu});return original.call(this,menu);};globalThis.ignored=new Map();const ignore=BrowserWindow.prototype.setIgnoreMouseEvents;BrowserWindow.prototype.setIgnoreMouseEvents=function(value,...args){globalThis.ignored.set(this.id,value);return ignore.call(this,value,...args);};globalThis.glassTest=require(${JSON.stringify(path.join(root,'main.cjs'))});`);
 let app;const errors=[],passed=[];const pass=name=>{passed.push(name);console.log('PASS:',name);};
 const launch=async()=>{
  app=await _electron.launch({executablePath:require('electron'),args:[wrapper],timeout:60000});
  app.on('window',p=>{p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error')console.error('Renderer:',m.text());});});
  await app.firstWindow();let control;for(let i=0;i<200&&!control;i++){control=app.windows().find(p=>p.url().endsWith('/control.html'));if(!control)await new Promise(r=>setTimeout(r,50));}
  if(!control)throw Error('Control not loaded: '+JSON.stringify(await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().map(w=>({title:w.getTitle(),url:w.webContents.getURL()})))));
  await control.waitForFunction(()=>window.glass&&document.getElementById('editor').value.length>0);
  let overlay;for(let i=0;i<100&&!overlay;i++){overlay=app.windows().find(p=>p.url().endsWith('/overlay.html'));if(!overlay)await new Promise(r=>setTimeout(r,50));}
  assert(overlay,'overlay window created');overlay.on('console',m=>{if(m.type()==='error'||m.type()==='warning')console.error('Overlay:',m.text());});await overlay.waitForFunction(()=>document.getElementById('text').textContent.length>0);
  return {control,overlay};
 };
 try{
  let {control,overlay}=await launch();
  const action=(name,value)=>control.evaluate(([n,v])=>window.glass.action(n,v),[name,value]);
  const ready=()=>control.evaluate(()=>window.glass.ready());
  const toolbar=app.windows().find(p=>p.url().endsWith('/unlock.html'));assert(toolbar);await toolbar.waitForFunction(()=>document.getElementById('unlock').textContent==='锁定');
  assert(await toolbar.evaluate(()=>Array.from(document.querySelectorAll('button')).every(el=>{const r=el.getBoundingClientRect();return r.bottom<=innerHeight&&r.right<=innerWidth;})));await toolbar.screenshot({path:path.join(out,'textbox-toolbar.png')});
  const environment=await app.evaluate(({app,screen,globalShortcut,BrowserWindow})=>({platform:process.platform,versions:process.versions,userData:app.getPath('userData'),displays:screen.getAllDisplays(),hotkey:globalShortcut.isRegistered('Control+Alt+G'),nativeTopmostAvailable:BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明文字').isAlwaysOnTop(),tray:globalThis.trays.every(t=>!t.tray.isDestroyed())}));
  assert.equal(environment.platform,'win32');assert.equal(environment.userData,data);assert(environment.tray);pass('Windows startup, isolated data, native tray creation');
  await control.screenshot({path:path.join(out,'control.png')});
  assert.equal((await ready()).state.color,'#000000');assert.equal((await ready()).state.outline,false);
  await control.locator('[data-tab=appearance]').click();await control.locator('#whiteText').click();assert.equal((await ready()).state.color,'#ffffff');await control.locator('#blackText').click();assert.equal((await ready()).state.color,'#000000');
  await action('spacing',32);await action('opacity',0.55);await action('backdrop',0.4);await action('weight','700');await action('alignment','center');
  await control.waitForFunction(()=>document.getElementById('opacityValue').textContent==='55%');
  assert.equal(await overlay.locator('#text').evaluate(el=>getComputedStyle(el).fontWeight),'700');assert.equal(await overlay.locator('#text').evaluate(el=>getComputedStyle(el).textAlign),'center');
  await control.screenshot({path:path.join(out,'appearance.png')});
  await control.locator('[data-tab=settings]').click();await action('bounds',{x:-9999,y:-9999,width:640,height:420});
  const resized=await ready();assert.equal(resized.state.bounds.width,640);assert.equal(resized.state.bounds.height,420);
  await action('bounds',{x:40,y:40,width:360,height:480});await toolbar.waitForFunction(()=>innerWidth<=340&&innerHeight>=130);assert(await toolbar.evaluate(()=>Array.from(document.querySelectorAll('button')).every(el=>{const r=el.getBoundingClientRect();return r.bottom<=innerHeight&&r.right<=innerWidth;})));await toolbar.screenshot({path:path.join(out,'textbox-toolbar-small.png')});
  await control.locator('#resetPosition').click();assert.equal((await ready()).state.locked,false);assert((await ready()).state.bounds.width>=640);
  await action('spacing',10);await action('opacity',1);await action('backdrop',0);await action('weight','500');await action('alignment','left');
  await control.locator('[data-tab=content]').click();await control.locator('#example').click();assert((await ready()).doc.text.includes('把资料放在手边'));pass('Mac appearance presets, live values, text rendering, window bounds/reset and example');
  await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明文字').setContentSize(360,500));
  await control.waitForFunction(()=>innerHeight===500);
  assert(await control.evaluate(()=>['lock','quit'].every(id=>{const r=document.getElementById(id).getBoundingClientRect();return r.top>=0&&r.bottom<=innerHeight&&r.right<=innerWidth;})));
  await control.screenshot({path:path.join(out,'small-control.png')});await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明文字').setContentSize(460,631));pass('Recovery and quit controls remain visible at 360 x 500');
  const text='Windows 中文测试 😀\n分页与重启恢复。\n'.repeat(100);
  await control.evaluate(t=>window.glass.text(t),text);await control.waitForFunction(()=>document.getElementById('pageStatus').textContent!=='1 / 1');
  await toolbar.locator('#nextPage').click();assert.equal((await ready()).state.page,1);await toolbar.locator('#plusZoom').click();assert.equal((await ready()).state.zoom,1.1);await toolbar.locator('#resetZoom').click();await action('zoom',1.5);assert.equal((await ready()).state.zoom,1.5);
  await toolbar.locator('#pin').click();await toolbar.waitForFunction(()=>document.getElementById('pin').getAttribute('aria-pressed')==='false');assert.equal((await ready()).state.topmost,false);await toolbar.locator('#pin').click();await toolbar.waitForFunction(()=>document.getElementById('pin').getAttribute('aria-pressed')==='true');await toolbar.locator('#appearance').click();assert(await control.locator('#appearance').isVisible());await toolbar.locator('#settings').click();assert(await control.locator('#settings').isVisible());await toolbar.locator('#content').click();assert(await control.locator('#content').isVisible());pass('Text-frame toolbar paging, zoom, topmost and content/appearance/settings buttons');
  await action('lockPaging',true);await action('lockZoom',true);await action('locked',true);await action('zoom',2);assert.equal((await ready()).state.zoom,1.5);
  const nativeState=await app.evaluate(({BrowserWindow})=>{const w=BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明展示');return {ignored:globalThis.ignored.get(w.id),topmost:w.isAlwaysOnTop()};});assert(nativeState.ignored);if(environment.nativeTopmostAvailable)assert(nativeState.topmost);else console.log('LIMITATION: current desktop does not expose native topmost, including a standalone test window; configuration tested');
  await overlay.screenshot({path:path.join(out,'locked-overlay.png'),omitBackground:true});
  assert(await toolbar.locator('#nextPage').isDisabled());assert(await toolbar.locator('#plusZoom').isDisabled());
  const toolbarVisible=()=>app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().find(w=>w.webContents.getURL().endsWith('/unlock.html')).isVisible());assert(await toolbarVisible());
  await toolbar.locator('#hideOverlay').click();assert.equal(await toolbarVisible(),false);await action('visible',true);
  await toolbar.locator('#unlock').click();assert.equal((await ready()).state.locked,false);assert(await toolbarVisible());await toolbar.locator('#unlock').click();assert.equal((await ready()).state.locked,true);await toolbar.locator('#unlock').click();assert.equal((await ready()).state.locked,false);pass('Text-frame lock/unlock, hide/show, native click-through configuration and lock guards');
  if(environment.hotkey){assert(await app.evaluate(({globalShortcut})=>globalShortcut.isRegistered('Control+Alt+G')));pass('Global recovery shortcut registered with Windows');}
  await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明文字').close());
  assert(await app.evaluate(()=>globalThis.trays.length>0));
  await app.evaluate(()=>{const {menu}=globalThis.trays[0];menu.items[0].click();});
  assert(await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().find(w=>w.getTitle()==='透明文字').isVisible()));pass('Close-to-tray and tray recovery callback');
  for(let i=0;i<9;i++)await action('snapshot');assert.equal(await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows().filter(w=>w.webContents.getURL().endsWith('/snapshot.html')).length),8);await action('clearSnapshots');pass('Eight-snapshot limit and cleanup');
  const docx=path.join(sourceRoot,'test/fixtures/sample.docx');await app.evaluate((_,file)=>globalThis.glassTest.importFile(file),docx);
  assert((await ready()).doc.text.includes('透明文字 Windows 导入测试'));
  await app.evaluate((_,file)=>globalThis.glassTest.importFile(file),path.join(data,'missing.docx'));assert((await ready()).doc.text.includes('透明文字 Windows 导入测试'));pass('DOCX import and failed import preserves document');
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>','<< /Length 27 >>\nstream\n0 0 0 rg 50 50 100 100 re f\nendstream'];
  let pdf='%PDF-1.4\n',offsets=[];objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(pdf));pdf+=`${i+1} 0 obj\n${o}\nendobj\n`;});const xref=Buffer.byteLength(pdf);pdf+='xref\n0 5\n0000000000 65535 f \n'+offsets.map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+`trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  const pdfFile=path.join(data,'中文 PDF.pdf');await fs.writeFile(pdfFile,pdf);await app.evaluate((_,f)=>globalThis.glassTest.importFile(f),pdfFile);
  await overlay.waitForFunction(()=>{const c=document.getElementById('pdf');return c.width>0&&c.style.display==='block';}).catch(async e=>{console.error('Import notice:',await control.locator('#notice').textContent());throw e;});assert.equal((await ready()).doc.kind,'pdf');
  assert(await control.locator('#textStyle').evaluate(el=>el.hidden));assert.equal(await control.locator('#pdfStyle').evaluate(el=>el.hidden),false);
  await overlay.waitForFunction(()=>document.getElementById('pdf').getContext('2d').getImageData(0,0,1,1).data[3]===0);
  await action('removeWhite',false);await overlay.waitForFunction(()=>document.getElementById('pdf').getContext('2d').getImageData(0,0,1,1).data[3]===255);
  await fs.writeFile(path.join(data,'broken.pdf'),'invalid PDF');await app.evaluate((_,f)=>globalThis.glassTest.importFile(f),path.join(data,'broken.pdf'));await control.waitForFunction(()=>document.getElementById('notice').textContent.includes('原内容保留'));assert.equal((await ready()).doc.name,'中文 PDF.pdf');pass('PDF worker, white removal, background toggle and invalid-PDF preservation');
  // Persist the latest document, page and style, then restart the real process.
  await control.evaluate(t=>window.glass.text(t),text);await control.waitForFunction(()=>document.getElementById('pageStatus').textContent!=='1 / 1');await action('page',1);await action('locked',true);
  await app.close();app=null;({control,overlay}=await launch());
  const restored=await control.evaluate(()=>window.glass.ready());assert.equal(restored.doc.text,text);assert.equal(restored.state.locked,false);assert.equal(restored.state.zoom,1.5);assert.equal(restored.state.page,1);pass('Quit/relaunch restores content, page and style in unlocked mode');
  assert.deepEqual(errors,[]);await fs.writeFile(path.join(out,'electron-results.json'),JSON.stringify({environment,passed,errors},null,2));
 }finally{await app?.close();console.log('Test data:',data);}
})().catch(e=>{console.error(e);process.exitCode=1;});
