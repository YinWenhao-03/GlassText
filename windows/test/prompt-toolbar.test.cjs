const {test}=require('node:test');const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');const {EventEmitter}=require('node:events');

test('v0.6.8 owned toolbar starts and pauses prompting while respecting document and lock guards',async()=>{
 const created=[],handlers=new Map(),area={x:0,y:0,width:1920,height:1080};
 class Window extends EventEmitter{
  constructor(options){super();this.options=options;this.bounds={x:options.x,y:options.y,width:options.width,height:options.height};this.focusable=options.focusable??true;this.messages=[];this.webContents=new EventEmitter();this.webContents.send=(...args)=>this.messages.push(args);this.webContents.setWindowOpenHandler=()=>{};this.webContents.session={setPermissionRequestHandler(){}};created.push(this);}
  isFocusable(){return this.focusable;}isVisible(){return this.visible;}getBounds(){return this.bounds;}setBounds(b){this.bounds=b;}isDestroyed(){return false;}loadFile(){return Promise.resolve();}
  setFocusable(value){this.focusable=value;}setAlwaysOnTop(){}setIgnoreMouseEvents(value){this.passthrough=value;}
  showInactive(){this.visible=true;}hide(){this.visible=false;}moveTop(){}show(){this.activated=true;}focus(){this.focused=true;}
 }
 const app=new EventEmitter();app.requestSingleInstanceLock=()=>true;app.whenReady=()=>Promise.resolve();app.getPath=()=>'/unused';
 const electron={app,BrowserWindow:Window,ipcMain:{handle:(name,fn)=>handlers.set(name,fn)},
  screen:{getPrimaryDisplay:()=>({workArea:area}),getAllDisplays:()=>[{id:1,workArea:area,size:area}],getDisplayMatching:()=>({id:1,workArea:area}),on(){}},
  Tray:class extends EventEmitter{setToolTip(){}setContextMenu(){}},Menu:{buildFromTemplate:()=>({}),setApplicationMenu(){}},
  nativeImage:{createFromPath:()=>({resize:()=>({})})},globalShortcut:{register:()=>true},dialog:{},shell:{}};
 const storage=require('../storage.cjs');
 const moduleValue={exports:{}};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../main.cjs'),'utf8'),{
  require:name=>name==='electron'?electron:name==='./storage.cjs'?{...storage,createStore:()=>({read:async()=>null,write:async()=>{}})}:name.startsWith('./')?require('../'+name.slice(2)):require(name),
  __dirname:path.resolve(__dirname,'..'),module:moduleValue,setTimeout:()=>0,clearTimeout(){},setInterval:()=>({unref(){}}),clearInterval(){},console,Buffer,AbortController
 });
 await new Promise(resolve=>setImmediate(resolve));
 assert.equal(created.length,3);const [control,overlay,toolbar]=created;
 assert.equal(toolbar.options.focusable,true);assert.equal(toolbar.options.parent,overlay);assert.equal(toolbar.options.frame,false);
 assert.equal(toolbar.options.webPreferences.sandbox,true);
 const event=win=>({sender:win.webContents});const action=(win,key,value)=>handlers.get('action')(event(win),key,value);
 const state=()=>handlers.get('ready')(event(toolbar)).state;
 handlers.get('pages')(event(overlay),5);await action(toolbar,'locked',true);
 assert.equal(overlay.passthrough,true);assert.equal(overlay.focusable,false);assert.equal(toolbar.passthrough,false);assert.equal(toolbar.focusable,true);
 await action(toolbar,'page',1);assert.equal(state().page,1);await action(toolbar,'zoom',1.5);assert.equal(state().zoom,1.5);
 assert(!control.activated);assert(!control.focused);
 await action(control,'lockPaging',true);await action(toolbar,'page',2);assert.equal(state().page,1);
 await action(toolbar,'locked',false);assert.equal(overlay.passthrough,false);assert.equal(toolbar.passthrough,false);
 await action(toolbar,'forget');assert.equal(state().page,1,'toolbar cannot clear documents');
 await handlers.get('action')({sender:{}},'page',3);assert.equal(state().page,1,'foreign senders are ignored');

 assert.equal(state().documentKind,'text');assert.equal(Object.hasOwn(handlers.get('ready')(event(toolbar)),'doc'),false);
 await action(control,'lockPaging',false);await action(toolbar,'locked',true);
 await action(toolbar,'togglePrompt');assert.equal(state().promptMode,true);assert.equal(state().prompting,true);assert.equal(state().locked,true);assert.equal(overlay.passthrough,true);
 assert(!control.activated);assert(!control.focused);
 handlers.get('progress')(event(overlay),{promptOffset:42});await action(toolbar,'togglePrompt');assert.equal(state().prompting,false);assert.equal(state().promptOffset,42);
 await action(toolbar,'togglePrompt');assert.equal(state().prompting,true);assert.equal(state().promptOffset,42);
 await action(control,'lockZoom',true);assert.equal(state().prompting,true);
 await action(control,'lockPaging',true);assert.equal(state().prompting,false);await action(toolbar,'togglePrompt');assert.equal(state().prompting,false);
 await action(control,'lockPaging',false);await action(toolbar,'togglePrompt');assert.equal(state().prompting,true);
 await handlers.get('action')({sender:{}},'togglePrompt');assert.equal(state().prompting,true);
 await action(overlay,'togglePrompt');assert.equal(state().prompting,true);
 await action(toolbar,'promptMode',false);assert.equal(state().promptMode,true,'toolbar only has access to its toggle command');
 await action(toolbar,'visible',false);assert.equal(toolbar.visible,false);assert.equal(overlay.visible,false);assert.equal(state().prompting,false);await action(toolbar,'togglePrompt');assert.equal(state().prompting,false);
 await action(control,'recover');assert.equal(toolbar.visible,true);assert.equal(overlay.visible,true);
 await action(control,'locked',false);
 const candidate=path.join(__dirname,'fixtures','candidate.pdf');
 const fsPromises=require('node:fs/promises');
 const originalStat=fsPromises.stat,originalRead=fsPromises.readFile;
 try{fsPromises.stat=async()=>({size:10});fsPromises.readFile=async()=>Buffer.from('mock PDF bytes');await moduleValue.exports.importFile(candidate);}finally{fsPromises.stat=originalStat;fsPromises.readFile=originalRead;}
 const id=overlay.messages.findLast(([name])=>name==='candidate')[1].id;handlers.get('pdf-result')(event(overlay),id,null);
 assert.equal(state().documentKind,'pdf');await action(toolbar,'togglePrompt');assert.equal(state().prompting,false);

});
