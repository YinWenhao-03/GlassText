const {app,BrowserWindow,ipcMain,dialog,globalShortcut,Menu,Tray,nativeImage,screen} = require('electron');
const fs=require('node:fs/promises'),path=require('node:path');
const mammoth=require('mammoth'); const {defaults,reduce}=require('./model.cjs');
let control,overlay,tray,state={...defaults},doc={kind:'text',text:'透明文字\n\n打开文件，或输入自己的文字。\n调整好位置后，点击锁定展示。',name:'示例'},quitting=false,sequence=0;
const windows=()=>[control,overlay].filter(w=>w&&!w.isDestroyed());
function send(){for(const w of windows())w.webContents.send('state',state);}
function deliver(){for(const w of windows())w.webContents.send('document',doc);}
function apply(){overlay.setAlwaysOnTop(state.topmost);overlay.setIgnoreMouseEvents(state.locked);if(state.visible)overlay.showInactive();else overlay.hide();send();}
function recover(){state=reduce(state,'recover');apply();control.show();control.focus();}
function secure(win){win.webContents.setWindowOpenHandler(()=>({action:'deny'}));win.webContents.on('will-navigate',e=>e.preventDefault());win.webContents.session.setPermissionRequestHandler((_w,_p,cb)=>cb(false));}
function allowed(event,role){return event.sender=== (role==='control'?control:overlay)?.webContents;}
async function importFile(file){
 const id=++sequence;pending=null;control.webContents.send('notice','正在读取…');
 try{
  const info=await fs.stat(file);if(info.size>50*1024*1024)throw new Error('文件超过 50 MB，请拆分后打开。');
  const ext=path.extname(file).toLowerCase();let next;
  if(ext==='.pdf')next={kind:'pdf',bytes:new Uint8Array(await fs.readFile(file)),name:path.basename(file)};
  else if(ext==='.docx'){const result=await mammoth.extractRawText({path:file});next={kind:'text',text:result.value,name:path.basename(file)};}
  else if(['.txt','.md'].includes(ext))next={kind:'text',text:await fs.readFile(file,'utf8'),name:path.basename(file)};
  else throw new Error('支持 PDF、DOCX、TXT、Markdown。旧版 DOC 请先另存为 DOCX 或 PDF。');
  if(next.kind==='text'&&(!next.text.trim()||next.text.length>2000000))throw new Error('文字为空或超过 200 万字符，请拆分文档。');
  if(id!==sequence)return;
  // PDF is validated in the isolated renderer before replacing the current document.
  if(next.kind==='pdf'){pending=next;overlay.webContents.send('candidate',{...next,id});return;}
  commit(next);
 }catch(error){if(id===sequence)control.webContents.send('notice',error.message+' 原内容已保留。');}
}
let pending;
function commit(next){pending=null;doc=next;state.page=0;state.pages=1;state.visible=true;apply();deliver();control.webContents.send('notice',doc.name);}
app.whenReady().then(async()=>{
 try{const saved=JSON.parse(await fs.readFile(path.join(app.getPath('userData'),'settings.json'),'utf8'));for(const k of ['zoom','font','color','outline','topmost','lockPaging','lockZoom'])state=reduce(state,k,saved[k]);}catch{}
 const area=screen.getPrimaryDisplay().workArea;
 const prefs={preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true};
 control=new BrowserWindow({width:460,height:670,x:area.x+20,y:area.y+30,title:'透明文字',webPreferences:prefs,icon:path.join(__dirname,'assets/icon.png')});
 overlay=new BrowserWindow({width:Math.min(850,area.width-60),height:Math.min(600,area.height-60),x:area.x+Math.max(30,area.width-900),y:area.y+40,transparent:true,frame:false,hasShadow:false,resizable:true,alwaysOnTop:true,webPreferences:prefs});
 for(const win of windows())secure(win);
 control.loadFile('control.html');overlay.loadFile('overlay.html');
 control.on('close',event=>{if(!quitting){event.preventDefault();control.hide();}});
 overlay.on('close',event=>{if(!quitting){event.preventDefault();state.visible=false;apply();}});
 const icon=nativeImage.createFromPath(path.join(__dirname,'assets/icon.png')).resize({width:24,height:24});tray=new Tray(icon);tray.setToolTip('透明文字');tray.setContextMenu(Menu.buildFromTemplate([{label:'恢复操作',click:recover},{label:'显示控制面板',click:()=>control.show()},{label:'退出',click:()=>{quitting=true;app.quit();}}]));tray.on('double-click',recover);
 state.hotkeyAvailable=globalShortcut.register('Control+Alt+G',recover);apply();
 screen.on('display-removed',()=>{const work=screen.getPrimaryDisplay().workArea;for(const win of windows()){let b=win.getBounds();win.setBounds({x:work.x+20,y:work.y+20,width:Math.min(b.width,work.width-40),height:Math.min(b.height,work.height-40)});}});
 Menu.setApplicationMenu(null);
});
ipcMain.handle('capture',async event=>{if(!allowed(event,'control'))return;return(await control.webContents.capturePage()).toDataURL();});
ipcMain.handle('ready',event=>{if(!windows().some(w=>w.webContents===event.sender))return;return{state,doc};});
ipcMain.handle('action',(event,command,value)=>{
 if(!allowed(event,'control')&&!allowed(event,'overlay'))return;
 if(allowed(event,'overlay')&&!['recover','page','zoom'].includes(command))return;
 if(command==='quit'&&allowed(event,'control')){quitting=true;app.quit();return;}
 if(command==='pan' && (!state.locked||!state.lockZoom)&&Array.isArray(value)&&value.length===2&&value.every(Number.isFinite)){overlay.webContents.send('pan',value);return;}
 if(command==='showControl'){control.show();return;}
 state=reduce(state,command,value);apply();
 fs.writeFile(path.join(app.getPath('userData'),'settings.json'),JSON.stringify(state)).catch(()=>{});
});
ipcMain.handle('open',async event=>{if(!allowed(event,'control'))return;const result=await dialog.showOpenDialog(control,{filters:[{name:'文档',extensions:['pdf','docx','txt','md']}],properties:['openFile']});if(!result.canceled)await importFile(result.filePaths[0]);});
ipcMain.handle('drop',(event,file)=>{if(allowed(event,'control')&&typeof file==='string')return importFile(file);});
ipcMain.handle('text',(event,text)=>{if(!allowed(event,'control')||typeof text!=='string'||text.length>2000000)return;sequence++;commit({kind:'text',text,name:'输入文字'});});
ipcMain.handle('cancel',event=>{if(allowed(event,'control')){sequence++;pending=null;control.webContents.send('notice','读取已取消，原内容保留。');}});
ipcMain.handle('pdf-result',(event,id,error)=>{if(!allowed(event,'overlay')||id!==sequence||!pending)return;if(error){pending=null;control.webContents.send('notice',String(error)+' 原内容保留。');}else commit(pending);});
ipcMain.handle('pages',(event,count)=>{if(!allowed(event,'overlay'))return;const next=reduce(state,'pages',count);if(next.pages!==state.pages||next.page!==state.page){state=next;send();}});
app.on('before-quit',()=>{quitting=true;});app.on('will-quit',()=>globalShortcut.unregisterAll());
