// Synthetic, isolated-process memory sample; not a universal performance guarantee.
const {_electron}=require('playwright-core');
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const source=path.resolve(__dirname,'..'),out=path.resolve(source,'../.work/windows-validation');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function samplePDF(){
 const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> /Contents 4 0 R >>','<< /Length 27 >>\nstream\n0 0 0 rg 50 50 100 100 re f\nendstream'];
 let pdf='%PDF-1.4\n%'+'.'.repeat(8*1024*1024)+'\n',offsets=[];
 objects.forEach((o,i)=>{offsets.push(Buffer.byteLength(pdf));pdf+=`${i+1} 0 obj\n${o}\nendobj\n`;});
 const xref=Buffer.byteLength(pdf);
 return pdf+'xref\n0 5\n0000000000 65535 f \n'+offsets.map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+`trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
}
async function measure(root,label){
 const data=await fs.mkdtemp(path.join(os.tmpdir(),'glass-memory-')),wrapper=path.join(data,'main.cjs');
 await fs.writeFile(wrapper,`const {app}=require('electron');app.setPath('userData',${JSON.stringify(data)});globalThis.testImport=require(${JSON.stringify(path.join(root,'main.cjs'))}).importFile;`);
 const app=await _electron.launch({executablePath:require('electron'),args:[wrapper]});
 try{
  await app.firstWindow();let control,overlay;
  for(let i=0;i<100;i++){control=app.windows().find(w=>w.url().endsWith('/control.html'));overlay=app.windows().find(w=>w.url().endsWith('/overlay.html'));if(control&&overlay)break;await sleep(50);}
  if(!control||!overlay)throw Error('Reader windows did not load');
  await overlay.waitForFunction(()=>document.getElementById('text').textContent.length>0);
  const collect=async()=>{await sleep(1600);return app.evaluate(({app})=>app.getAppMetrics().reduce((sum,p)=>({processes:sum.processes+1,workingSetKiB:sum.workingSetKiB+p.memory.workingSetSize,privateKiB:sum.privateKiB+(p.memory.privateBytes||0)}),{processes:0,workingSetKiB:0,privateKiB:0}));};
  const text=await collect(),file=path.join(data,'memory.pdf');
  await fs.writeFile(file,samplePDF());await app.evaluate((_,f)=>globalThis.testImport(f),file);
  await overlay.waitForFunction(()=>{const c=document.getElementById('pdf');return c.width>0&&c.style.display==='block';});
  const visiblePDF=await collect();
  await control.evaluate(()=>window.glass.action('visible',false));
  const hiddenPDF=await collect(),hiddenCanvas=await overlay.evaluate(()=>{const c=document.getElementById('pdf');return{width:c.width,height:c.height};});
  const result={label,text,visiblePDF,hiddenPDF,hiddenCanvas};console.log(JSON.stringify(result));return result;
 }finally{await app.close();}
}
(async()=>{
 const results=[];
 if(process.env.GLASSTEXT_BASELINE_ROOT)results.push(await measure(path.resolve(process.env.GLASSTEXT_BASELINE_ROOT),'baseline'));
 results.push(await measure(process.env.GLASSTEXT_APP_ROOT||source,'candidate'));
 await fs.mkdir(out,{recursive:true});await fs.writeFile(path.join(out,'memory-results.json'),JSON.stringify(results,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
