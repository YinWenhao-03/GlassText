const defaults = {locked:false, lockPaging:false, lockZoom:false, zoom:1, page:0, pages:1, topmost:true, visible:true, color:'#ffffff', font:36, outline:true, removeWhite:true, preserveLayout:false, promptMode:false, prompting:false, speed:30,whiteStrength:1,opacity:1,backdrop:0,spacing:0,weight:'400',alignment:'left'};
function reduce(state, command, value) {
  const s = {...defaults, ...state};
  const canPage = !s.locked || !s.lockPaging, canZoom = !s.locked || !s.lockZoom;
  if (command === 'page' && canPage && Number.isFinite(value)) s.page = Math.min(s.pages-1, Math.max(0, Math.trunc(value)));
  if (command === 'zoom' && canZoom && Number.isFinite(value)) s.zoom = Math.min(3,Math.max(.5,value));
  if (['locked','lockPaging','lockZoom','topmost','visible','outline','removeWhite','preserveLayout','promptMode'].includes(command) && typeof value === 'boolean') s[command] = value;
  if (command === 'font' && canZoom && Number.isFinite(value)) s.font = Math.min(96,Math.max(16,value));
  if (command === 'color' && /^#[0-9a-f]{6}$/i.test(value)) s.color = value;
  if (['whiteStrength','opacity','backdrop'].includes(command) && Number.isFinite(value)) s[command]=Math.min(1,Math.max(command==='opacity'?.1:0,value));
  if (command==='spacing' && Number.isFinite(value)) s.spacing=Math.min(30,Math.max(0,value));
  if (command==='weight' && ['400','500','700'].includes(value)) s.weight=value;
  if (command==='alignment' && ['left','center','right'].includes(value)) s.alignment=value;
  if (command === 'speed' && Number.isFinite(value)) s.speed = Math.min(100,Math.max(5,value));
  if (command === 'prompting' && typeof value === 'boolean' && canPage) s.prompting = value;
  if ((s.locked && s.lockPaging) || !s.promptMode || !s.visible) s.prompting = false;
  if (command === 'recover') {s.locked = false; s.visible = true;}
  if (command === 'pages' && Number.isFinite(value)) {s.pages = Math.max(1,Math.trunc(value));s.page = Math.min(s.page,s.pages-1);}
  return s;
}
module.exports = {defaults,reduce};
