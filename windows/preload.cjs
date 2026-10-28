const {contextBridge,ipcRenderer,webUtils}=require('electron');
contextBridge.exposeInMainWorld('glass',{
 capture:()=>ipcRenderer.invoke('capture'),
 ready:()=>ipcRenderer.invoke('ready'), action:(name,value)=>ipcRenderer.invoke('action',name,value),
 open:()=>ipcRenderer.invoke('open'),text:value=>ipcRenderer.invoke('text',value),cancel:()=>ipcRenderer.invoke('cancel'),
 drop:file=>ipcRenderer.invoke('drop',webUtils.getPathForFile(file)),
 reportError:value=>ipcRenderer.invoke('render-error',value),progress:value=>ipcRenderer.invoke('progress',value),promptStatus:value=>ipcRenderer.invoke('prompt-status',value),
 pages:count=>ipcRenderer.invoke('pages',count),pdfResult:(id,error)=>ipcRenderer.invoke('pdf-result',id,error),
 listen:(name,fn)=>{if(['state','document','notice','candidate','pan','prompt-reset','prompt-status','select-tab'].includes(name))ipcRenderer.on(name,(_event,payload)=>fn(payload));}
});
