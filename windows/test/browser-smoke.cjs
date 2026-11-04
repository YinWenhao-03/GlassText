// Renderer integration checks. This does not verify native Electron/Windows behavior.
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),http=require('node:http');
const {chromium}=require('playwright-core');const {defaults,reduce}=require('../model.cjs');
(async()=>{
 const root=path.resolve(__dirname,'..'),types={'.mjs':'text/javascript','.js':'text/javascript','.html':'text/html','.css':'text/css','.png':'image/png'};
 const server=http.createServer(async(req,res)=>{try{const file=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!file.startsWith(root+path.sep))throw Error();res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(await fs.readFile(file));}catch{res.statusCode=404;res.end();}});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 let browser;try{
  browser=await chromium.launch({executablePath:process.env.GLASSTEXT_BROWSER,headless:true,args:['--disable-gpu','--disable-background-timer-throttling','--disable-backgrounding-occluded-windows','--disable-renderer-backgrounding']});
  const context=await browser.newContext({viewport:{width:460,height:710}}),errors=[];
  const control=await context.newPage(),overlay=await context.newPage(),toolbar=await context.newPage();await overlay.clock.install();await overlay.setViewportSize({width:800,height:600});
  let state={...defaults,hotkeyAvailable:true},doc={kind:'text',text:'透明文字\n测试资料\n'.repeat(80),name:'合成测试文档'};
  const broadcast=async(name,value)=>{for(const page of [control,overlay,toolbar])await page.evaluate(({name,value})=>window.testListeners?.[name]?.(value),{name,value:name==='state'?{...value,documentKind:doc.kind}:value});};
  for(const page of [control,overlay,toolbar]){
   page.on('pageerror',e=>{errors.push(e.message);console.error('Renderer exception:',e.message);});
   await page.exposeFunction('testReady',()=>({state:{...state,documentKind:doc.kind},doc}));
   await page.exposeFunction('testAction',async(key,value)=>{if(key==='togglePrompt'){if(doc.kind!=='text'||!state.visible||(state.locked&&state.lockPaging))return;const running=state.prompting;state=reduce(state,'promptMode',true);state=reduce(state,'prompting',!running);}else state=reduce(state,key,value);await broadcast('state',state);});
   await page.exposeFunction('testPages',async count=>{const next=reduce(state,'pages',count);if(next.pages!==state.pages||next.page!==state.page){state=next;await broadcast('state',state);}});
   await page.exposeFunction('testProgress',value=>{state.promptOffset=value.promptOffset;});
   await page.exposeFunction('testPromptStatus',async value=>{await overlay.evaluate(v=>window.lastPromptStatus=v,value);if(value==='已到结尾'){state.prompting=false;await broadcast('state',state);}});
   await page.exposeFunction('testText',async text=>{doc={kind:'text',text,name:'输入文字'};state={...state,page:0};await broadcast('document',doc);});
   await page.addInitScript(()=>{window.testListeners={};window.glass={ready:window.testReady,action:window.testAction,pages:window.testPages,text:window.testText,listen:(name,fn)=>window.testListeners[name]=fn,reportError:value=>{throw Error(value);},progress:window.testProgress,promptStatus:window.testPromptStatus,open:()=>{},drop:()=>{},cancel:()=>{},pdfResult:()=>{},capture:async()=>''};});
  }
  const url='http://127.0.0.1:'+server.address().port;
  await control.goto(url+'/control.html');await overlay.goto(url+'/overlay.html');await toolbar.goto(url+'/unlock.html');
  await control.waitForFunction(()=>document.getElementById('editor').value.length>0);
  await overlay.waitForFunction(()=>document.getElementById('text').textContent.length>0);
  assert.equal(await overlay.evaluate(()=>performance.getEntriesByType('resource').some(r=>r.name.includes('pdfjs-dist'))),false,'text reading does not load PDF engine');
  assert(state.pages>1,'text paginated');await control.bringToFront();
  await control.locator('#next').dispatchEvent('click');await overlay.waitForTimeout(100);assert.equal(state.page,1);
  await control.locator('#plus').dispatchEvent('click');assert.equal(state.zoom,1.1);
  await control.locator('[data-tab=settings]').dispatchEvent('click');await control.evaluate(()=>{for(const id of ['lockPaging','lockZoom']){const el=document.getElementById(id);el.checked=true;el.dispatchEvent(new Event('change'));}});await control.locator('#lock').dispatchEvent('click');
  assert(await control.isDisabled('#next'));assert(await control.isDisabled('#plus'));
  const lockedPage=state.page;await control.evaluate(()=>window.glass.action('page',8));assert.equal(state.page,lockedPage);
  await control.locator('#lock').dispatchEvent('click');await control.locator('[data-tab=prompter]').dispatchEvent('click');await control.evaluate(()=>{const el=document.getElementById('promptMode');el.checked=true;el.dispatchEvent(new Event('change'));});await control.locator('#prompting').dispatchEvent('click');
  await overlay.clock.runFor(3600);assert(await overlay.evaluate(()=>document.getElementById('viewport').scrollTop>0),'prompter scrolls after countdown');
  await control.locator('#prompting').dispatchEvent('click');await overlay.waitForFunction(()=>window.lastPromptStatus==='已暂停');const stopped=await overlay.evaluate(()=>document.getElementById('viewport').scrollTop);await overlay.clock.runFor(200);assert.equal(await overlay.evaluate(()=>document.getElementById('viewport').scrollTop),stopped);
  // The frame button starts text prompting directly, including while locked.
  await control.evaluate(()=>{window.glass.action('lockPaging',false);window.glass.action('locked',true);window.glass.action('promptMode',false);});
  await toolbar.bringToFront();await toolbar.setViewportSize({width:760,height:104});
  await toolbar.locator('#togglePrompt').click();assert(state.promptMode&&state.prompting&&state.locked);
  await overlay.clock.runFor(1500);const duringCountdown=await overlay.evaluate(()=>document.getElementById('viewport').scrollTop);
  await toolbar.locator('#togglePrompt').click();await overlay.clock.runFor(4000);assert.equal(await overlay.evaluate(()=>document.getElementById('viewport').scrollTop),duringCountdown,'countdown can be cancelled');
  await toolbar.locator('#togglePrompt').click();await overlay.clock.runFor(3600);
  const advanced=await overlay.evaluate(()=>document.getElementById('viewport').scrollTop);assert(advanced>duringCountdown);
  await toolbar.locator('#togglePrompt').click();await overlay.clock.runFor(300);assert.equal(await overlay.evaluate(()=>document.getElementById('viewport').scrollTop),advanced);
  await toolbar.keyboard.press('Control+Shift+P');assert(state.prompting);await overlay.clock.runFor(3600);assert(await overlay.evaluate(()=>document.getElementById('viewport').scrollTop)>advanced);
  await control.evaluate(()=>window.glass.action('lockPaging',true));assert(!state.prompting);assert(await toolbar.locator('#togglePrompt').isDisabled());
  await toolbar.keyboard.press('Control+Shift+P');assert(!state.prompting);
  await control.evaluate(()=>window.glass.action('lockPaging',false));
  await toolbar.keyboard.press('Control+Shift+P');assert(state.prompting);await control.evaluate(()=>window.glass.action('visible',false));assert(!state.prompting);
  await control.evaluate(()=>window.glass.action('visible',true));
  for(const [width,height] of [[760,104],[700,136],[440,136],[336,168]]){
   await toolbar.setViewportSize({width,height});
   assert(await toolbar.evaluate(()=>Array.from(document.querySelectorAll('button')).every(el=>{const r=el.getBoundingClientRect();return r.right<=innerWidth&&r.bottom<=innerHeight;})),`toolbar buttons fit ${width} x ${height}`);
  }
  await control.locator('[data-tab=settings]').dispatchEvent('click');assert(await control.locator('#forget').isVisible());
  await control.locator('#forget').evaluate(el=>el.scrollIntoView());assert.equal(await control.evaluate(()=>document.querySelector('main').scrollHeight>document.querySelector('main').clientHeight),true);
  await control.locator('[data-tab=content]').dispatchEvent('click');
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>','<< /Length 27 >>\nstream\n0 0 0 rg 50 50 100 100 re f\nendstream'];
  let source='%PDF-1.4\n',offsets=[0];objects.forEach((object,i)=>{offsets.push(Buffer.byteLength(source));source+=`${i+1} 0 obj\n${object}\nendobj\n`;});const xref=Buffer.byteLength(source);source+='xref\n0 5\n0000000000 65535 f \n'+offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+`trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  doc={kind:'pdf',bytes:[...Buffer.from(source)],name:'合成 PDF'};await broadcast('state',state);await broadcast('document',doc);assert(await toolbar.locator('#togglePrompt').isDisabled());await toolbar.keyboard.press('Control+Shift+P');assert(!state.prompting);
  await overlay.waitForFunction(()=>{const c=document.getElementById('pdf');return c.width>0&&c.style.display==='block';});
  assert.equal(await overlay.evaluate(()=>document.getElementById('pdf').getContext('2d').getImageData(0,0,1,1).data[3]),0);
  await control.evaluate(()=>window.glass.action('removeWhite',false));
  await overlay.waitForFunction(()=>document.getElementById('pdf').getContext('2d').getImageData(0,0,1,1).data[3]===255);
  await overlay.setViewportSize({width:2000,height:1800});
  await control.evaluate(()=>{window.glass.action('locked',false);window.glass.action('zoom',3);});
  await overlay.clock.runFor(200);
  await overlay.waitForFunction(()=>{const c=document.getElementById('pdf');return c.width>2500;});
  assert(await overlay.evaluate(()=>{const c=document.getElementById('pdf');return c.width*c.height<=8*1024*1024+8192;}),'large zoom stays within 32 MiB canvas budget plus rounding');
  await control.evaluate(()=>window.glass.action('visible',false));await overlay.waitForFunction(()=>document.getElementById('pdf').width===0);
  await control.evaluate(()=>window.glass.action('visible',true));await overlay.waitForFunction(()=>document.getElementById('pdf').width>0);
  await control.evaluate(()=>window.glass.text('切换回文字，释放 PDF 画布'));await overlay.waitForFunction(()=>document.getElementById('pdf').width===0&&document.getElementById('text').textContent.includes('释放 PDF'));
  assert.deepEqual(errors,[]);console.log('PASS: toolbar prompter click/shortcut, narrow layouts, PDF and lock guards, countdown cancellation and resume; renderer pagination, zoom, countdown/scroll/pause, settings overflow, PDF render/background toggle; no renderer exceptions');
 }finally{await browser?.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
