// 语程 — 视图渲染模块
// 职责: renderAll、renderProgress、renderCards、renderEditForm、卡片交互 (startEdit/saveEdit/delEvt/togDone)

// ===== Core Render =====
function renderAll() {
  renderProgress();
  renderCards();
}
function renderProgress() {
  var ev = getEvts(selectedDate);
  var t = ev.length;
  var d = 0;
  for (var i = 0; i < t; i++) { if (ev[i].done) d++; }
  var r = t - d;
  var p = t > 0 ? Math.round(d/t*100) : 0;
  document.getElementById('totalCount').textContent = t;
  document.getElementById('doneCount').textContent = d;
  document.getElementById('remainCount').textContent = r;
  document.getElementById('pgBarFill').style.width = p + '%';
}
function renderCards() {
  var c = document.getElementById('cardStream');
  var ev = getEvts(selectedDate);
  ev.sort(function(a,b){ return (a.time||'99:99').localeCompare(b.time||'99:99'); });
  var now = new Date();
  var isTdy = (selectedDate === todayKey);
  var nmin = now.getHours()*60 + now.getMinutes();

  if (ev.length === 0) {
    c.innerHTML = '<div class="empty-state"><div class="empty-icon">&#x1F4C3;</div><div>' +
      (selectedDate === todayKey ? '今天还没有行程' : '这天没有行程') + '</div></div>';
    return;
  }

  var h = '';
  for (var i = 0; i < ev.length; i++) {
    var e = ev[i];
    var isD = e.done === true;
    var isA = false;
    if (!isD && isTdy) {
      var pp = (e.time||'99:99').split(':');
      var em = parseInt(pp[0])*60 + parseInt(pp[1]);
      var nm = 9999;
      if (i+1 < ev.length) {
        var np = (ev[i+1].time||'99:99').split(':');
        nm = parseInt(np[0])*60 + parseInt(np[1]);
      }
      if (em <= nmin && nmin < nm) isA = true;
      if (i === ev.length-1 && em <= nmin) isA = true;
    }

    if (_editIdx === i) {
      h += renderEditForm(e, i);
    } else {
      var tc = TAG_COLORS[e.tag] || 'tg-l';
      h += '<div class="evt-card' + (isA?' activ':'') + (isD?' don':'') + '" id="ec-'+i+'">';
      h += '<div class="evt-time">' + (e.time||'--:--') + '</div>';
      h += '<div class="evt-body" onclick="startEdit('+i+')">';
      h += '<div class="evt-text">' + esc(e.content) + '</div>';
      h += '<div class="evt-meta"><span class="evt-tag '+tc+'">' + esc(e.tag||'生活') + '</span></div>';
      h += '</div>';
      h += '<div class="evt-chk" onclick="event.stopPropagation();togDone('+i+')">' + (isD?'✓':'') + '</div>';
      h += gifBgHtml();
      h += '</div>';
    }
  }
  c.innerHTML = h;
}

function renderEditForm(e, idx) {
  var h = '<div class="edit-form" id="ef-'+idx+'">';
  h += '<div class="er"><input type="time" id="etm-'+idx+'" value="'+(e.time||'09:00')+'"><input type="text" id="ect-'+idx+'" value="'+escAttr(e.content)+'" placeholder="行程内容"></div>';
  h += '<div class="et">';
  for (var t=0; t<ALL_TAGS.length; t++) {
    h += '<button class="et-btn'+(e.tag===ALL_TAGS[t]?' sel':'')+'" onclick="selETag('+idx+',\''+ALL_TAGS[t]+'\')">'+ALL_TAGS[t]+'</button>';
  }
  h += '</div>';
  h += '<div class="ea"><button class="btn-can" onclick="cancelEdit()">取消</button><button class="btn-del" onclick="delEvt('+idx+')">删除</button><button class="btn-sv" onclick="saveEdit('+idx+')">保存</button></div>';
  h += '</div>';
  return h;
}

function esc(s) { if(!s)return''; return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function escAttr(s) { if(!s)return''; return s.replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

function startEdit(idx) {
  if (_editIdx === idx) { cancelEdit(); return; }
  _editIdx = idx;
  renderCards();
}
function cancelEdit() { _editIdx = -1; renderCards(); }
function selETag(idx, tag) {
  var ev = getEvts(selectedDate);
  if (idx<0||idx>=ev.length) return;
  ev[idx].tag = tag;
  var btns = document.querySelectorAll('#ef-'+idx+' .et-btn');
  btns.forEach(function(b){ b.classList.toggle('sel', b.textContent===tag); });
}
function saveEdit(idx) {
  var ev = getEvts(selectedDate);
  if (idx<0||idx>=ev.length) return;
  var tm = document.getElementById('etm-'+idx);
  var ct = document.getElementById('ect-'+idx);
  if (!tm || !ct) return;
  var nt = ct.value.trim();
  if (!nt) return;
  ev[idx].time = tm.value;
  ev[idx].content = nt;
  var sb = document.querySelector('#ef-'+idx+' .et-btn.sel');
  if (sb) ev[idx].tag = sb.textContent;
  saveEvents();
  _editIdx = -1;
  renderAll();
}
function delEvt(idx) {
  var ev = getEvts(selectedDate);
  if (idx<0||idx>=ev.length) return;
  ev.splice(idx, 1);
  saveEvents();
  _editIdx = -1;
  renderAll();
}
function togDone(idx) {
  var ev = getEvts(selectedDate);
  if (idx<0||idx>=ev.length) return;
  ev[idx].done = !ev[idx].done;
  saveEvents();
  renderAll();
}
