import * as pdfjs from './node_modules/pdfjs-dist/build/pdf.mjs';
pdfjs.GlobalWorkerOptions.workerSrc=new URL('./node_modules/pdfjs-dist/build/pdf.worker.mjs',import.meta.url).href;
let state,doc,pdfDoc,pages=[''],generation=0,renderTask,renderSerial=0;const viewport=document.getElementById('viewport'),text=document.getElementById('text'),canvas=document.getElementById('pdf');
function paginate(value){
 const chars=Array.from(value);pages=[];let start=0;const height=viewport.clientHeight;
 text.style.display='block';text.style.fontSize=state.font*state.zoom+'px';
 while(start<chars.length){let low=1,high=Math.min(chars.length-start,15000),fit=1;
  while(low<=high){const mid=Math.floor((low+high)/2);text.textContent=chars.slice(start,start+mid).join('');if(text.scrollHeight<=height+1){fit=mid;low=mid+1;}else high=mid-1;}
  // Prefer a line break without dropping any characters.
  let chunk=chars.slice(start,start+fit).join(''),br=chunk.lastIndexOf('\n');if(br>chunk.length*.5&&start+fit<chars.length)fit=Array.from(chunk.slice(0,br+1)).length;
  pages.push(chars.slice(start,start+fit).join(''));start+=fit;
 }
 if(!pages.length)pages=[''];window.glass.pages(pages.length);
}
async function openPDF(bytes){return pdfjs.getDocument({data:new Uint8Array(bytes),isEvalSupported:false,enableXfa:false}).promise;}
window.glass.listen('pan',delta=>viewport.scrollBy(delta[0],delta[1]));
window.glass.listen('candidate',async candidate=>{
 try{const check=await openPDF(candidate.bytes);if(check.numPages<1)throw new Error('PDF 没有页面');await check.destroy();window.glass.pdfResult(candidate.id,null);}catch(error){window.glass.pdfResult(candidate.id,'PDF 无法读取或需要密码。');}
});
async function documentChanged(value){
 const id=++generation;const previous=pdfDoc;pdfDoc=null;doc=value;
 if(value.kind==='pdf'){const next=await openPDF(value.bytes);if(id!==generation){await next.destroy();return;}pdfDoc=next;await previous?.destroy();window.glass.pages(next.numPages);}
 else{await previous?.destroy();paginate(value.text);}
 await render();
}
async function render(){
 if(!state||!doc)return;document.body.classList.toggle('locked',state.locked);
 text.style.color=state.color;text.style.fontSize=state.font*state.zoom+'px';text.style.textShadow=state.outline?(state.color==='#000000'?'0 1px 1px white,1px 0 1px white,-1px 0 1px white':'0 1px 2px black,1px 0 2px black,-1px 0 2px black'):'none';
 if(doc.kind==='text'){canvas.style.display='none';text.style.display='block';text.textContent=pages[Math.min(state.page,pages.length-1)]??'';viewport.scrollTop=0;return;}
 if(!pdfDoc)return;text.style.display='none';canvas.style.display='block';const serial=++renderSerial;
 renderTask?.cancel();
 try{
  const page=await pdfDoc.getPage(Math.min(state.page+1,pdfDoc.numPages));if(serial!==renderSerial)return;
  const raw=page.getViewport({scale:1}),fit=Math.min(viewport.clientWidth/raw.width,viewport.clientHeight/raw.height);
  const cssScale=fit*state.zoom,ratio=Math.min(2,window.devicePixelRatio||1),view=page.getViewport({scale:cssScale*ratio});
  // Bound canvas memory for large source pages and high-DPI screens.
  const cap=Math.min(1,4096/Math.max(view.width,view.height)),bounded=page.getViewport({scale:cssScale*ratio*cap});
  canvas.width=Math.ceil(bounded.width);canvas.height=Math.ceil(bounded.height);canvas.style.width=raw.width*cssScale+'px';canvas.style.height=raw.height*cssScale+'px';
  const ctx=canvas.getContext('2d',{willReadFrequently:true});renderTask=page.render({canvasContext:ctx,viewport:bounded,background:'white'});await renderTask.promise;if(serial!==renderSerial)return;
  const image=ctx.getImageData(0,0,canvas.width,canvas.height),p=image.data;
  for(let i=0;i<p.length;i+=4){const w=Math.min(p[i],p[i+1],p[i+2]),alpha=255-w;p[i+3]=alpha;if(alpha){p[i]=Math.round((p[i]-w)*255/alpha);p[i+1]=Math.round((p[i+1]-w)*255/alpha);p[i+2]=Math.round((p[i+2]-w)*255/alpha);}}
  ctx.putImageData(image,0,0);
 }catch(error){if(error.name!=='RenderingCancelledException')console.error('Page rendering failed',error.message);}
}
window.glass.listen('state',next=>{const reflow=state&&(next.zoom!==state.zoom||next.font!==state.font);state=next;if(reflow&&doc?.kind==='text')paginate(doc.text);render();});
window.glass.listen('document',value=>documentChanged(value));
let resizeTimer;window.onresize=()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>{if(doc?.kind==='text')paginate(doc.text);render();},120);};
const initial=await window.glass.ready();state=initial.state;await documentChanged(initial.doc);
