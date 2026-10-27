const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os');
const {clampBounds,createStore}=require('../storage.cjs');
test('removed displays and oversized windows recover within work area',()=>{
 const area={x:0,y:0,width:1920,height:1080};
 assert.deepEqual(clampBounds({x:6000,y:0,width:3000,height:2000},[area]),{x:0,y:0,width:1920,height:1080});
 const left={x:-1920,y:0,width:1920,height:1080};
 assert.deepEqual(clampBounds({x:-1800,y:30,width:800,height:600},[area,left]),{x:-1800,y:30,width:800,height:600});
});
test('serialized atomic writes preserve latest session and clearing replaces document',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'glass-store-test-'));
 try{
  const store=createStore(dir);
  await Promise.all(Array.from({length:20},(_,page)=>store.write('session',{page})));
  assert.equal((await store.read('session')).page,19);
  await store.write('document',{text:'私人测试内容'});await store.write('document',{text:''});
  assert.equal((await store.read('document')).text,'');
  assert.equal(await store.read('missing'),null);
  assert.deepEqual((await fs.readdir(dir)).sort(),['document.json','session.json']);
 }finally{await fs.rm(dir,{recursive:true,force:true});}
});
