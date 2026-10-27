const {app,BrowserWindow,ipcMain,dialog,globalShortcut,Menu,Tray,nativeImage,screen,shell} = require('electron');
const fs=require('node:fs/promises'),path=require('node:path');
const mammoth=require('mammoth'); const {defaults,reduce}=require('./model.cjs');
const {clampBounds,createStore}=require('./storage.cjs');const {convertWord}=require('./convert.cjs');
const snapshots=new Set();
let store,savedSession,saveTimer,importController;
function saveSession(){if(quitting)return;clearTimeout(saveTimer);saveTimer=setTimeout(()=>{store.write('session',{state:{...state,prompting:false,locked:false},bounds:overlay.getBounds()}).catch(()=>control.webContents.send('notice','阅读位置保存失败，请检查磁盘空间。'));},250);}
function saveDocument(){return store.write('document',{...doc,bytes:doc.bytes?Buffer.from(doc.bytes).toString('base64'):undefined}).catch(()=>control.webContents.send('notice','阅读内容保存失败，请检查磁盘空间。'));}
let control,overlay,tray,state={...defaults},doc={kind:'text',text:'透明文字\n\n打开文件，或输入自己的文字。\n调整好位置后，点击锁定展示。',name:'示例'},quitting=false,sequence=0;
const windows=()=>[control,overlay].filter(w=>w&&!w.isDestroyed());
function send(){for(const w of windows())w.webContents.send('state',state);}
function deliver(){for(const w of windows())w.webContents.send('document',doc);}
function apply(){for(const win of snapshots){win.setAlwaysOnTop(state.topmost);win.setIgnoreMouseEvents(state.locked);if(state.visible)win.showInactive();else win.hide();}overlay.setAlwaysOnTop(state.topmost);overlay.setIgnoreMouseEvents(state.locked);if(state.visible)overlay.showInactive();else overlay.hide();send();}
function recover(){for(const win of snapshots)win.setBounds(clampBounds(win.getBounds(),screen.getAllDisplays().map(d=>d.workArea)));overlay.setBounds(clampBounds(overlay.getBounds(),screen.getAllDisplays().map(d=>d.workArea)));state=reduce(state,'recover');apply();control.show();control.focus();}
function secure(win){win.webContents.setWindowOpenHandler(()=>({action:'deny'}));win.webContents.on('will-navigate',e=>e.preventDefault());win.webContents.session.setPermissionRequestHandler((_w,_p,cb)=>cb(false));}
function allowed(event,role){return event.sender=== (role==='control'?control:overlay)?.webContents;}
async function importFile(file){
 importController?.abort();importController=new AbortController();const signal=importController.signal;const id=++sequence;pending=null;control.webContents.send('notice','正在读取…');
 try{
  const info=await fs.stat(file);if(info.size>50*1024*1024)throw new Error('文件超过 50 MB，请拆分后打开。');
  const ext=path.extname(file).toLowerCase();let next;
  if(ext==='.pdf')next={kind:'pdf',bytes:new Uint8Array(await fs.readFile(file)),name:path.basename(file)};
  else if(['.doc','.rtf'].includes(ext)||(ext==='.docx'&&state.preserveLayout))next={kind:'pdf',bytes:await convertWord(file,signal),name:path.basename(file)};
  else if(ext==='.docx'){const result=await mammoth.extractRawText({path:file});next={kind:'text',text:result.value,name:path.basename(file)};}
  else if(['.txt','.md'].includes(ext))next={kind:'text',text:await fs.readFile(file,'utf8'),name:path.basename(file)};
  else throw new Error('支持 PDF、DOCX、TXT、Markdown。旧版 DOC 请先另存为 DOCX 或 PDF。');
  if(next.kind==='text'&&(!next.text.trim()||next.text.length>2000000))throw new Error('文字为空或超过 200 万字符，请拆分文档。');
  if(id!==sequence)return;
  // PDF is validated in the isolated renderer before replacing the current document.
  if(next.kind==='pdf'){control.webContents.send('notice','正在验证 PDF…');pending=next;overlay.webContents.send('candidate',{...next,id});return;}
  commit(next);
 }catch(error){if(id===sequence)control.webContents.send('notice',error.message+' 原内容已保留。');}
}
let pending;
function commit(next){pending=null;doc=next;state.page=0;state.pages=1;state.prompting=false;state.promptOffset=0;state.pan=[0,0];state.visible=true;apply();deliver();saveDocument();saveSession();control.webContents.send('notice',doc.name);}
app.whenReady().then(async()=>{
 store=createStore(app.getPath('userData'));savedSession=await store.read('session');
 const saved=savedSession?.state||await store.read('settings');
 if(saved){for(const k of ['zoom','font','color','outline','topmost','lockPaging','lockZoom','removeWhite','preserveLayout','promptMode','speed','whiteStrength','opacity','backdrop','spacing','weight','alignment'])state=reduce(state,k,saved[k]);state.page=Math.max(0,Math.trunc(saved.page)||0);state.pages=Math.max(1,state.page+1);state.promptOffset=Math.max(0,Number(saved.promptOffset)||0);state.pan=Array.isArray(saved.pan)?saved.pan:[0,0];state.shortcut=saved.shortcut;}
 const restored=await store.read('document');if(restored?.kind==='text'&&typeof restored.text==='string'&&restored.text.length<=2000000)doc=restored;
 else if(restored?.kind==='pdf'&&typeof restored.bytes==='string'&&restored.bytes.length<70000000)doc={...restored,bytes:new Uint8Array(Buffer.from(restored.bytes,'base64'))};
 const area=screen.getPrimaryDisplay().workArea;
 const prefs={preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false};
 control=new BrowserWindow({width:460,height:670,x:area.x+20,y:area.y+30,title:'透明文字',webPreferences:prefs,icon:path.join(__dirname,'assets/icon.png')});
 overlay=new BrowserWindow({width:Math.min(850,area.width-60),height:Math.min(600,area.height-60),x:area.x+Math.max(30,area.width-900),y:area.y+40,transparent:true,frame:false,hasShadow:false,resizable:true,alwaysOnTop:true,webPreferences:prefs});
 if(savedSession?.bounds)overlay.setBounds(clampBounds(savedSession.bounds,screen.getAllDisplays().map(d=>d.workArea)));
 overlay.on('move',saveSession);overlay.on('resize',saveSession);
 for(const win of windows())secure(win);
 control.loadFile(path.join(__dirname,'control.html'));overlay.loadFile(path.join(__dirname,'overlay.html'));
 control.on('close',event=>{if(!quitting){event.preventDefault();control.hide();}});
 overlay.on('close',event=>{if(!quitting){event.preventDefault();state.visible=false;state.prompting=false;apply();saveSession();}});
 const icon=nativeImage.createFromPath(path.join(__dirname,'assets/icon.png')).resize({width:24,height:24});tray=new Tray(icon);tray.setToolTip('透明文字');tray.setContextMenu(Menu.buildFromTemplate([{label:'恢复操作',click:recover},{label:'显示控制面板',click:()=>control.show()},{label:'退出',click:()=>{quitting=true;app.quit();}}]));tray.on('double-click',recover);
 try{state.hotkeyAvailable=globalShortcut.register(state.shortcut||'Control+Alt+G',recover);}catch{state.hotkeyAvailable=false;}apply();
 screen.on('display-removed',()=>{const work=screen.getPrimaryDisplay().workArea;for(const win of [...windows(),...snapshots]){let b=win.getBounds();win.setBounds({x:work.x+20,y:work.y+20,width:Math.min(b.width,work.width-40),height:Math.min(b.height,work.height-40)});}});
 function displayList(){state.displays=screen.getAllDisplays().map((d,i)=>({id:d.id,label:d.label||`屏幕 ${i+1} (${d.size.width} × ${d.size.height})`}));state.displayId=screen.getDisplayMatching(overlay.getBounds()).id;send();}
 screen.on('display-added',displayList);screen.on('display-removed',displayList);overlay.on('move',displayList);displayList();
 Menu.setApplicationMenu(null);
});
ipcMain.handle('capture',async event=>{if(!allowed(event,'control'))return;return(await control.webContents.capturePage()).toDataURL();});
ipcMain.handle('ready',event=>{if(!windows().some(w=>w.webContents===event.sender))return;return{state,doc};});
ipcMain.handle('action',async(event,command,value)=>{
 if(!allowed(event,'control')&&!allowed(event,'overlay'))return;
 if(allowed(event,'overlay')&&!['recover','page','zoom'].includes(command))return;
 if(command==='display'){const target=screen.getAllDisplays().find(d=>d.id===value);if(target){overlay.setBounds(clampBounds({...overlay.getBounds(),x:target.workArea.x+30,y:target.workArea.y+30},[target.workArea]));saveSession();}return;}
 if(command==='clearSnapshots'){for(const win of snapshots)win.close();return;}
 if(command==='snapshot'){
  if(snapshots.size>=8){control.webContents.send('notice','最多固定 8 个画面，请先关闭部分画面。');return;}
  const rect=await overlay.webContents.executeJavaScript("(()=>{const r=document.getElementById('viewport').getBoundingClientRect();return {x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.width),height:Math.round(r.height)};})()");
  const image=await overlay.webContents.capturePage(rect),b=overlay.getBounds();
  const win=new BrowserWindow({...clampBounds({x:b.x+30,y:b.y+30,width:rect.width,height:rect.height},screen.getAllDisplays().map(d=>d.workArea)),transparent:true,frame:false,hasShadow:false,webPreferences:{sandbox:true,contextIsolation:true,nodeIntegration:false}});
  secure(win);snapshots.add(win);win.webContents.on('context-menu',()=>Menu.buildFromTemplate([{label:'关闭此画面',click:()=>win.close()}]).popup({window:win}));win.on('closed',()=>snapshots.delete(win));
  await win.loadFile(path.join(__dirname,'snapshot.html'));await win.webContents.executeJavaScript('document.getElementById("image").src='+JSON.stringify(image.toDataURL()));apply();control.webContents.send('notice','已固定当前画面；随主窗口一起锁定或恢复，右键关闭。');return;
 }
 if(command==='recover'){recover();return;}
 if(command==='updates'){shell.openExternal('https://github.com/YinWenhao-03/GlassText/releases');return;}
 if(command==='shortcut'&&typeof value==='string'){
  if(!/^(?:(?:Control|Alt|Shift|Super)\+){1,3}[A-Z0-9]$/i.test(value)){control.webContents.send('notice','格式示例：Control+Alt+G，至少包含一个修饰键。');return;}
  if(value===(state.shortcut||'Control+Alt+G')&&state.hotkeyAvailable)return;
  let ok=false;try{ok=globalShortcut.register(value,recover);}catch{}
  if(!ok){control.webContents.send('notice','快捷键无效或被占用，原快捷键保持可用。');return;}
  globalShortcut.unregister(state.shortcut||'Control+Alt+G');state.shortcut=value;state.hotkeyAvailable=true;send();saveSession();return;
 }
 if(command==='forget'){importController?.abort();sequence++;commit({kind:'text',text:'',name:'已清除阅读记录'});return;}
 if(command==='promptMode'&&state.locked&&state.lockPaging)return;
 if(command==='prompting'&&doc.kind!=='text')return;
 if(command==='promptReset'&&(!state.locked||!state.lockPaging)){state.promptOffset=0;overlay.webContents.send('prompt-reset');saveSession();return;}
 if(command==='quit'&&allowed(event,'control')){quitting=true;app.quit();return;}
 if(command==='pan' && (!state.locked||!state.lockZoom)&&Array.isArray(value)&&value.length===2&&value.every(Number.isFinite)){overlay.webContents.send('pan',value);return;}
 if(command==='showControl'){control.show();return;}
 state=reduce(state,command,value);apply();
 saveSession();
});
ipcMain.handle('open',async event=>{if(!allowed(event,'control'))return;const result=await dialog.showOpenDialog(control,{filters:[{name:'文档',extensions:['pdf','docx','doc','rtf','txt','md']}],properties:['openFile']});if(!result.canceled)await importFile(result.filePaths[0]);});
ipcMain.handle('drop',(event,file)=>{if(allowed(event,'control')&&typeof file==='string')return importFile(file);});
ipcMain.handle('text',(event,text)=>{if(!allowed(event,'control')||typeof text!=='string'||text.length>2000000)return;importController?.abort();sequence++;commit({kind:'text',text,name:'输入文字'});});
ipcMain.handle('cancel',event=>{if(allowed(event,'control')){importController?.abort();sequence++;pending=null;control.webContents.send('notice','读取已取消，原内容保留。');}});
ipcMain.handle('pdf-result',(event,id,error)=>{if(!allowed(event,'overlay')||id!==sequence||!pending)return;if(error){pending=null;control.webContents.send('notice',String(error)+' 原内容保留。');}else commit(pending);});
ipcMain.handle('pages',(event,count)=>{if(!allowed(event,'overlay'))return;const next=reduce(state,'pages',count);if(next.pages!==state.pages||next.page!==state.page){state=next;send();saveSession();}});
ipcMain.handle('render-error',(event,message)=>{if(allowed(event,'overlay')&&typeof message==='string')control.webContents.send('notice',message.slice(0,200));});
ipcMain.handle('progress',(event,value)=>{if(!allowed(event,'overlay')||!value)return;if(Number.isFinite(value.promptOffset))state.promptOffset=Math.max(0,value.promptOffset);if(Array.isArray(value.pan)&&value.pan.length===2&&value.pan.every(Number.isFinite))state.pan=value.pan;saveSession();});
ipcMain.handle('prompt-status',(event,message)=>{if(allowed(event,'overlay')&&typeof message==='string'){control.webContents.send('prompt-status',message.slice(0,120));if(message==='已到结尾'){state.prompting=false;send();}}});
let flushed=false;app.on('before-quit',event=>{quitting=true;sequence++;importController?.abort();if(!flushed&&store){event.preventDefault();clearTimeout(saveTimer);store.write('session',{state:{...state,prompting:false,locked:false},bounds:overlay.getBounds()}).catch(()=>{}).finally(()=>{flushed=true;app.quit();});}});app.on('will-quit',()=>globalShortcut.unregisterAll());

module.exports={importFile};
