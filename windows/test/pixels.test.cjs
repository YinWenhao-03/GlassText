const {test}=require('node:test');const assert=require('node:assert/strict');
test('PDF white removal preserves black, colour and existing transparency',async()=>{
 const {removeWhite}=await import('../pixels.mjs');
 assert.deepEqual([...removeWhite(new Uint8ClampedArray([255,255,255,255,0,0,0,255,255,0,0,255,0,0,0,0]))],[255,255,255,0,0,0,0,255,255,0,0,255,0,0,0,0]);
 const gray=removeWhite(new Uint8ClampedArray([128,128,128,255]));assert.deepEqual([...gray],[0,0,0,127]);
});
