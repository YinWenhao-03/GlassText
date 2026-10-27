const {test} = require('node:test'); const assert = require('node:assert/strict'); const {defaults,reduce} = require('../model.cjs');
test('lock choices independently prevent paging and zoom',()=>{
 const s={...defaults,pages:10,locked:true,lockPaging:true};
 assert.equal(reduce(s,'page',3).page,0); assert.equal(reduce(s,'zoom',2).zoom,2);
 const t={...s,lockPaging:false,lockZoom:true}; assert.equal(reduce(t,'page',3).page,3);assert.equal(reduce(t,'zoom',2).zoom,1);
});
test('recover always restores control',()=>{const s=reduce({...defaults,locked:true,visible:false},'recover');assert.equal(s.locked,false);assert.equal(s.visible,true);});
test('zoom/page boundaries and invalid input',()=>{assert.equal(reduce(defaults,'zoom',100).zoom,3);assert.equal(reduce(defaults,'zoom',0).zoom,.5);assert.equal(reduce(defaults,'zoom',NaN).zoom,1);assert.equal(reduce({...defaults,pages:5},'page',100).page,4);});
test('paging lock pauses prompter while zoom lock does not',()=>{
 const running={...defaults,promptMode:true,prompting:true,locked:true};
 assert.equal(reduce(running,'lockPaging',true).prompting,false);
 assert.equal(reduce(running,'lockZoom',true).prompting,true);
 assert.equal(reduce({...running,lockPaging:true},'prompting',true).prompting,false);
 assert.equal(reduce(running,'visible',false).prompting,false);
 assert.equal(reduce(running,'promptMode',false).prompting,false);
});
test('prompter speed and PDF background settings are bounded',()=>{
 assert.equal(reduce(defaults,'speed',999).speed,100);
 assert.equal(reduce(defaults,'speed',-4).speed,5);
 assert.equal(reduce(defaults,'removeWhite',false).removeWhite,false);
 assert.equal(reduce(defaults,'removeWhite','false').removeWhite,true);
});
