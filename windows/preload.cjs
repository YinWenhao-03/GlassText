const {contextBridge,ipcRenderer,webUtils}=require('electron');
contextBridge.exposeInMainWorld('glass',{
 capture:()=>ipcRenderer.invoke('capture'),
 ready:()=>ipcRenderer.invoke('ready'), action:(name,value)=>ipcRenderer.invoke('action',name,value),
 open:()=>ipcRenderer.invoke('open'),text:value=>ipcRenderer.invoke('text',value),cancel:()=>ipcRenderer.invoke('cancel'),
 drop:file=>ipcRenderer.invoke('drop',webUtils.getPathForFile(file)),
 pages:count=>ipcRenderer.invoke('pages',count),pdfResult:(id,error)=>ipcRenderer.invoke('pdf-result',id,error),
 listen:(name,fn)=>{if(['state','document','notice','candidate','pan'].includes(name))ipcRenderer.on(name,(_event,payload)=>fn(payload));}
});
