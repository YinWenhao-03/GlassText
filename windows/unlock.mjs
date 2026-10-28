const $=id=>document.getElementById(id);let state;
function paint(s){state=s;$('unlock').textContent=s.locked?'解锁 · 返回调整':'锁定';$('unlock').setAttribute('aria-label',s.locked?'解锁展示并返回调整':'锁定文本框');$('pageLabel').textContent=`${s.page+1} / ${s.pages}`;$('zoomLabel').textContent=Math.round(s.zoom*100)+'%';$('pin').setAttribute('aria-pressed',String(s.topmost));$('pin').textContent=s.topmost?'已置顶':'置顶';for(const id of ['prevPage','nextPage'])$(id).disabled=s.locked&&s.lockPaging;for(const id of ['minusZoom','plusZoom','resetZoom'])$(id).disabled=s.locked&&s.lockZoom;$('toolbarStatus').textContent=s.locked?'已锁定 · 正文鼠标穿透；此工具栏可操作':'调整中 · 拖动上方标题移动文本框';}
const action=(name,value)=>window.glass.action(name,value);
$('unlock').onclick=()=>state.locked?action('recover'):action('locked',true);
$('prevPage').onclick=()=>action('page',state.page-1);$('nextPage').onclick=()=>action('page',state.page+1);
$('minusZoom').onclick=()=>action('zoom',state.zoom-.1);$('plusZoom').onclick=()=>action('zoom',state.zoom+.1);$('resetZoom').onclick=()=>action('zoom',1);
$('pin').onclick=()=>action('topmost',!state.topmost);$('content').onclick=()=>action('showContent');$('appearance').onclick=()=>action('showSettings','appearance');$('settings').onclick=()=>action('showSettings','settings');$('hideOverlay').onclick=()=>action('visible',false);
window.glass.listen('state',paint);paint((await window.glass.ready()).state);
