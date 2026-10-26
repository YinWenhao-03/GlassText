const defaults = {locked:false, lockPaging:false, lockZoom:false, zoom:1, page:0, pages:1, topmost:true, visible:true, color:'#ffffff', font:36, outline:true};
function reduce(state, command, value) {
  const s = {...defaults, ...state};
  const canPage = !s.locked || !s.lockPaging, canZoom = !s.locked || !s.lockZoom;
  if (command === 'page' && canPage && Number.isFinite(value)) s.page = Math.min(s.pages-1, Math.max(0, Math.trunc(value)));
  if (command === 'zoom' && canZoom && Number.isFinite(value)) s.zoom = Math.min(3,Math.max(.5,value));
  if (['locked','lockPaging','lockZoom','topmost','visible','outline'].includes(command) && typeof value === 'boolean') s[command] = value;
  if (command === 'font' && canZoom && Number.isFinite(value)) s.font = Math.min(96,Math.max(16,value));
  if (command === 'color' && /^#[0-9a-f]{6}$/i.test(value)) s.color = value;
  if (command === 'recover') {s.locked = false; s.visible = true;}
  if (command === 'pages' && Number.isFinite(value)) {s.pages = Math.max(1,Math.trunc(value));s.page = Math.min(s.page,s.pages-1);}
  return s;
}
module.exports = {defaults,reduce};
