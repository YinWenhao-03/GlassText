const fs=require('node:fs/promises'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process');const {pathToFileURL}=require('node:url');
async function convertWord(file,signal){
 const candidates=[process.env.ProgramFiles,process.env['ProgramFiles(x86)']].filter(Boolean).flatMap(p=>['soffice.com','soffice.exe'].map(name=>path.join(p,'LibreOffice','program',name)));
 if(process.platform==='darwin')candidates.push('/Applications/LibreOffice.app/Contents/MacOS/soffice');
 let executable;for(const candidate of candidates){try{await fs.access(candidate);executable=candidate;break;}catch{}}
 if(!executable)throw new Error('请安装 LibreOffice 后使用 Word 保留版式，或先将文档导出为 PDF。');
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'glasstext-'));
 try{
  const input=path.join(dir,'document'+path.extname(file).toLowerCase());await fs.copyFile(file,input);
  await new Promise((resolve,reject)=>{
   if(signal.aborted)return reject(new Error('读取已取消'));
   const child=spawn(executable,['-env:UserInstallation='+pathToFileURL(path.join(dir,'profile')).href,'--headless','--convert-to','pdf','--outdir',dir,input],{windowsHide:true,stdio:'ignore'});
   let failure;const stop=message=>{failure=new Error(message);child.kill();};
   const cancel=()=>stop('读取已取消');signal.addEventListener('abort',cancel,{once:true});
   const timer=setTimeout(()=>stop('转换超过 45 秒，请在 Word 中导出 PDF 后重试。'),45000);
   child.once('error',error=>{clearTimeout(timer);signal.removeEventListener('abort',cancel);reject(error);});
   child.once('close',code=>{clearTimeout(timer);signal.removeEventListener('abort',cancel);failure?reject(failure):code===0?resolve():reject(new Error('Word 转换失败，请导出 PDF 后重试。'));});
  });
  const output=path.join(dir,'document.pdf');
  if((await fs.stat(output)).size>50*1024*1024)throw new Error('转换后的 PDF 超过 50 MB，请拆分文档。');
  return new Uint8Array(await fs.readFile(output));
 }finally{await fs.rm(dir,{recursive:true,force:true}).catch(()=>{});}
}
module.exports={convertWord};
