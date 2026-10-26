const $=id=>document.getElementById(id);let state,step=0,currentDoc;
function tab(id){document.querySelectorAll('main section').forEach(el=>el.hidden=el.id!==id);document.querySelectorAll('nav button').forEach(el=>el.classList.toggle('active',el.dataset.tab===id));}
document.querySelectorAll('[data-tab]').forEach(el=>el.onclick=()=>tab(el.dataset.tab));
function paint(s){state=s;$('mode').textContent=s.locked?'已锁定 · 鼠标穿透；点击“返回调整”恢复':'调整中 · 拖动展示窗口顶部移动';$('lock').textContent=s.locked?'返回调整':'锁定展示';$('pageStatus').textContent=`${s.page+1} / ${s.pages}`;$('page').value=s.page+1;$('zoom').textContent=Math.round(s.zoom*100)+'%';$('visible').textContent=s.visible?'隐藏':'显示';for(const key of ['topmost','outline','lockPaging','lockZoom'])$(key).checked=s[key];$('font').value=s.font;$('color').value=s.color;for(const key of ['prev','next','page','jump'])$(key).disabled=s.locked&&s.lockPaging;for(const key of ['minus','plus','fit','font','panLeft','panUp','panDown','panRight'])$(key).disabled=s.locked&&s.lockZoom;$('font').disabled=currentDoc?.kind==='pdf'||(s.locked&&s.lockZoom);$('hotkey').textContent=s.hotkeyAvailable?'全局恢复：Ctrl + Alt + G':'恢复快捷键被占用，请用任务栏托盘“恢复操作”。';}
for(const [id,delta] of [['panLeft',[-80,0]],['panRight',[80,0]],['panUp',[0,-80]],['panDown',[0,80]]])$(id).onclick=()=>window.glass.action('pan',delta);
const action=(key,value)=>window.glass.action(key,value);
$('open').onclick=()=>window.glass.open();$('cancel').onclick=()=>window.glass.cancel();$('apply').onclick=()=>window.glass.text($('editor').value);
$('prev').onclick=()=>action('page',state.page-1);$('next').onclick=()=>action('page',state.page+1);$('jump').onclick=()=>action('page',Number($('page').value)-1);$('page').onkeydown=e=>{if(e.key==='Enter')$('jump').click();};
$('minus').onclick=()=>action('zoom',state.zoom-.1);$('plus').onclick=()=>action('zoom',state.zoom+.1);$('fit').onclick=()=>action('zoom',1);
$('lock').onclick=()=>action('locked',!state.locked);$('visible').onclick=()=>action('visible',!state.visible);$('quit').onclick=()=>action('quit');
for(const key of ['topmost','outline','lockPaging','lockZoom'])$(key).onchange=()=>action(key,$(key).checked);
$('font').oninput=()=>action('font',Number($('font').value));$('color').oninput=()=>action('color',$('color').value);
window.glass.listen('state',paint);window.glass.listen('notice',text=>$('notice').textContent=text);
function showDocument(doc){currentDoc=doc;$('notice').textContent=doc.name;if(doc.kind==='text')$('editor').value=doc.text;$('font').disabled=doc.kind==='pdf'||(state.locked&&state.lockZoom);}
window.glass.listen('document',showDocument);
document.addEventListener('dragover',e=>e.preventDefault());document.addEventListener('drop',e=>{e.preventDefault();if(e.dataTransfer.files[0])window.glass.drop(e.dataTransfer.files[0]);});
const instructions=[['先放入内容','content','① 点击打开文件，或拖入文档。\n② 输入文字后点击“显示这段文字”。','open'],['调整外观','appearance','① 选择文字颜色与字号。\n② 建议保持描边，适应不同背景。','font'],['锁定与恢复','content','① 点击锁定展示，鼠标就能穿透。\n② 点击返回调整，或按 Ctrl + Alt + G 恢复。','lock'],['选择锁定范围','settings','① 翻页和缩放可以分别锁定。\n② 未勾选时，仍能通过面板操作。','settings']];
async function guide(){
 const [title,section,explanation,target]=instructions[step];
 if($('help').open)$('help').close();tab(section);
 await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
 const box=$(target).getBoundingClientRect(),shot=await window.glass.capture();
 const image=new Image();image.src=shot;await image.decode();
 const canvas=$('shot');canvas.width=image.width;canvas.height=image.height;const ctx=canvas.getContext('2d');ctx.drawImage(image,0,0);
 const ratio=image.width/window.innerWidth;ctx.strokeStyle='#ef4444';ctx.lineWidth=4*ratio;ctx.strokeRect((box.x-3)*ratio,(box.y-3)*ratio,(box.width+6)*ratio,(box.height+6)*ratio);
 $('helpTitle').textContent=`${step+1}/4 · ${title}`;$('helpText').textContent=explanation;$('helpPrev').disabled=step===0;$('helpNext').textContent=step===3?'完成':'下一步';$('help').showModal();
}
$('guide').onclick=()=>{step=0;guide();};$('helpPrev').onclick=()=>{step--;guide();};$('helpNext').onclick=()=>{if(step===3)$('help').close();else{step++;guide();}};$('helpClose').onclick=()=>$('help').close();
const initial=await window.glass.ready();paint(initial.state);showDocument(initial.doc);
