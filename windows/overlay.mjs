import {removeWhite} from './pixels.mjs';
import * as pdfjs from './node_modules/pdfjs-dist/build/pdf.mjs';
pdfjs.GlobalWorkerOptions.workerSrc=new URL('./node_modules/pdfjs-dist/build/pdf.worker.mjs',import.meta.url).href;
let state,doc,pdfDoc,pages=[''],generation=0,renderTask,renderSerial=0;const viewport=document.getElementById('viewport'),text=document.getElementById('text'),canvas=document.getElementById('pdf');
function paginate(value){
 const chars=Array.from(value);pages=[];let start=0;const height=viewport.clientHeight;
 text.style.display='block';text.style.fontSize=state.font*state.zoom+'px';text.style.fontWeight=state.weight;text.style.lineHeight=(state.font*state.zoom*1.45+state.spacing)+'px';
 while(start<chars.length){let low=1,high=Math.min(chars.length-start,15000),fit=1;
  while(low<=high){const mid=Math.floor((low+high)/2);text.textContent=chars.slice(start,start+mid).join('');if(text.scrollHeight<=height+1){fit=mid;low=mid+1;}else high=mid-1;}
  // Prefer a line break without dropping any characters.
  let chunk=chars.slice(start,start+fit).join(''),br=chunk.lastIndexOf('\n');if(br>chunk.length*.5&&start+fit<chars.length)fit=Array.from(chunk.slice(0,br+1)).length;
  pages.push(chars.slice(start,start+fit).join(''));start+=fit;
 }
 if(!pages.length)pages=[''];window.glass.pages(pages.length);
}
const pdfTasks=new WeakMap();
async function openPDF(bytes){const task=pdfjs.getDocument({data:new Uint8Array(bytes),isEvalSupported:false,enableXfa:false});try{const document=await task.promise;pdfTasks.set(document,task);return document;}catch(error){await task.destroy().catch(()=>{});throw error;}}
async function closePDF(document){const task=document&&pdfTasks.get(document);if(task){pdfTasks.delete(document);await task.destroy();}}
let promptY=0,countdownUntil=0,lastFrame=0,progressTick=0,lastStatus='';
function promptStatus(value){if(value!==lastStatus){lastStatus=value;window.glass.promptStatus(value);}}
function reportPosition(){window.glass.progress({promptOffset:promptY,pan:[viewport.scrollLeft,viewport.scrollTop]});}
viewport.addEventListener('scroll',()=>{if(!progressTick)progressTick=setTimeout(()=>{progressTick=0;reportPosition();},250);});
window.glass.listen('prompt-reset',()=>{promptY=0;viewport.scrollTop=0;});
function tick(now){
 if(state?.prompting&&state.promptMode&&doc?.kind==='text'&&(!state.locked||!state.lockPaging)){
  if(now<countdownUntil){promptStatus('准备：'+Math.ceil((countdownUntil-now)/1000));}
  else {promptStatus('提词中');promptY+=Math.min(100,now-(lastFrame||now))/1000*state.speed;const end=Math.max(0,text.scrollHeight-viewport.clientHeight);promptY=Math.min(promptY,end);viewport.scrollTop=promptY;if(promptY>=end){state.prompting=false;promptStatus('已到结尾');}}
 }lastFrame=now;requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
window.glass.listen('pan',delta=>viewport.scrollBy(delta[0],delta[1]));
window.glass.listen('candidate',async candidate=>{
 let check;try{check=await openPDF(candidate.bytes);if(check.numPages<1)throw new Error('PDF 没有页面');await closePDF(check);window.glass.pdfResult(candidate.id,null);}catch(error){await closePDF(check).catch(()=>{});window.glass.pdfResult(candidate.id,'PDF 无法读取或需要密码。');}
});
async function documentChanged(value){
 const id=++generation;const previous=pdfDoc;pdfDoc=null;doc=value;promptY=state.promptOffset||0;renderSerial++;renderTask?.cancel();
 if(value.kind==='pdf'){const next=await openPDF(value.bytes);if(id!==generation){await closePDF(next);return;}pdfDoc=next;await closePDF(previous);if(id!==generation)return;window.glass.pages(next.numPages);}
 else{await closePDF(previous);if(id!==generation)return;if(!state.promptMode)paginate(value.text);else window.glass.pages(1);}
 await render();
}
async function render(){
 if(!state||!doc)return;viewport.style.background=`rgba(0,0,0,${state.backdrop})`;text.style.opacity=canvas.style.opacity=state.opacity;text.style.textAlign=state.alignment;document.body.classList.toggle('locked',state.locked);
 text.style.color=state.color;text.style.fontSize=state.font*state.zoom+'px';text.style.fontWeight=state.weight;text.style.lineHeight=(state.font*state.zoom*1.45+state.spacing)+'px';text.style.textShadow=state.outline?(state.color==='#000000'?'0 1px 1px white,1px 0 1px white,-1px 0 1px white':'0 1px 2px black,1px 0 2px black,-1px 0 2px black'):'none';
 if(doc.kind==='text'){canvas.style.display='none';text.style.display='block';text.textContent=state.promptMode?doc.text:(pages[Math.min(state.page,pages.length-1)]??'');viewport.scrollTop=state.promptMode?promptY:0;return;}
 if(!pdfDoc)return;text.style.display='none';canvas.style.display='block';const serial=++renderSerial;
 const previousTask=renderTask;previousTask?.cancel();
 try{
  if(previousTask)await previousTask.promise.catch(()=>{});if(serial!==renderSerial)return;
  const page=await pdfDoc.getPage(Math.min(state.page+1,pdfDoc.numPages));if(serial!==renderSerial)return;
  const raw=page.getViewport({scale:1}),fit=Math.min(viewport.clientWidth/raw.width,viewport.clientHeight/raw.height);
  const cssScale=fit*state.zoom,ratio=Math.min(2,window.devicePixelRatio||1),view=page.getViewport({scale:cssScale*ratio});
  // Bound canvas memory for large source pages and high-DPI screens.
  const cap=Math.min(1,4096/Math.max(view.width,view.height)),bounded=page.getViewport({scale:cssScale*ratio*cap});
  canvas.width=Math.ceil(bounded.width);canvas.height=Math.ceil(bounded.height);canvas.style.width=raw.width*cssScale+'px';canvas.style.height=raw.height*cssScale+'px';
  const ctx=canvas.getContext('2d',{willReadFrequently:true});renderTask=page.render({canvasContext:ctx,viewport:bounded,background:'white'});await renderTask.promise;if(serial!==renderSerial)return;
  if(state.removeWhite){const image=ctx.getImageData(0,0,canvas.width,canvas.height),p=image.data;
  removeWhite(p,state.whiteStrength);
  ctx.putImageData(image,0,0);}
  viewport.scrollLeft=state.pan?.[0]||0;viewport.scrollTop=state.pan?.[1]||0;
 }catch(error){if(error.name!=='RenderingCancelledException')window.glass.reportError('页面无法渲染，请尝试缩小页面或重新打开文件。');}
}
window.glass.listen('state',next=>{
 const old=state,reflow=old&&(next.zoom!==old.zoom||next.font!==old.font||next.promptMode!==old.promptMode||next.spacing!==old.spacing||next.weight!==old.weight);
 if(next.prompting&&!old?.prompting)countdownUntil=performance.now()+3000;
 if(!next.prompting&&old?.prompting)promptStatus('已暂停');
 state=next;
 if(reflow&&doc?.kind==='text'){if(state.promptMode)window.glass.pages(1);else paginate(doc.text);}
 if(!old||['zoom','font','promptMode','page','color','outline','removeWhite','locked','whiteStrength','opacity','backdrop','spacing','weight','alignment'].some(k=>old[k]!==next[k]))render();
});
window.glass.listen('document',value=>documentChanged(value).catch(()=>window.glass.reportError('文档无法恢复，请重新打开文件。')));
let resizeTimer;window.onresize=()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>{if(doc?.kind==='text'&&!state.promptMode)paginate(doc.text);render();},120);};
const initial=await window.glass.ready();state=initial.state;await documentChanged(initial.doc).catch(()=>window.glass.reportError('文档无法恢复，请重新打开文件。'));
