const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),mammoth=require('mammoth');
test('Chinese DOCX is extracted without markup',async()=>{const r=await mammoth.extractRawText({path:path.join(__dirname,'fixtures/sample.docx')});assert.ok(r.value.includes('透明文字 Windows 导入测试'));assert.ok(r.value.includes('保留中文与换行。'));assert.ok(!r.value.includes('<w:'));});
test('missing document is rejected',async()=>{await assert.rejects(()=>mammoth.extractRawText({path:path.join(__dirname,'fixtures/missing.docx')}));});
