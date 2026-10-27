const fs=require('node:fs/promises');
const path=require('node:path');
function clampBounds(bounds,areas){
 const b=bounds&&['x','y','width','height'].every(key=>Number.isFinite(bounds[key]))?bounds:{x:0,y:0,width:850,height:600};
 const a=areas.find(a=>b.x<a.x+a.width&&b.x+b.width>a.x&&b.y<a.y+a.height&&b.y+b.height>a.y)||areas[0];
 const width=Math.min(Math.max(320,b.width),a.width),height=Math.min(Math.max(240,b.height),a.height);
 return {width,height,x:Math.min(Math.max(b.x,a.x),a.x+a.width-width),y:Math.min(Math.max(b.y,a.y),a.y+a.height-height)};
}
function createStore(directory){
 let queue=Promise.resolve();
 return {
  async read(name){try{return JSON.parse(await fs.readFile(path.join(directory,name+'.json'),'utf8'));}catch{return null;}},
  write(name,value){const payload=JSON.stringify(value);queue=queue.catch(()=>{}).then(async()=>{await fs.mkdir(directory,{recursive:true});const file=path.join(directory,name+'.json');await fs.writeFile(file+'.tmp',payload,{mode:0o600});await fs.rename(file+'.tmp',file);});return queue;},
  flush(){return queue;}
 };
}
module.exports={clampBounds,createStore};
