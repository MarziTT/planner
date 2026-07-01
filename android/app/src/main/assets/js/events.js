// 语程 — 事件数据层
// 职责: events对象管理、saveEvents/getEvts、CRUD操作、添加面板、设置面板

var events = {};

function saveEvents() {
  var dates = Object.keys(events);
  for (var i = 0; i < dates.length; i++) {
    var dk = dates[i];
    var evts = events[dk];
    for (var j = 0; j < evts.length; j++) {
      var ev = evts[j];
      var apiEv = {
        id: ev.id,
        date: dk,
        title: ev.content || ev.title || '',
        time: ev.time || '',
        end_time: ev.endTime || '',
        tags: ev.tag ? [ev.tag] : (ev.tags || []),
        completed: ev.done || ev.completed || false,
        notes: ev.notes || ''
      };
      (function(idx, dateKey) {
        apiSaveEvent(apiEv).then(function(saved) {
          if (saved && saved.id && events[dateKey] && events[dateKey][idx]) {
            events[dateKey][idx].id = saved.id;
          }
        }).catch(function() { /* silent */ });
      })(j, dk);
    }
  }
}

function getEvts(dk) { return events[dk] || []; }

// ==================== 添加面板 ====================
// ===== Add Panel =====
function openAddPanel() {
  _editIdx = -1;
  document.getElementById('addPanel').classList.add('on');
  document.getElementById('addOvl').classList.add('on');
  document.getElementById('addCt').focus();
}
function closeAddPanel() {
  document.getElementById('addPanel').classList.remove('on');
  document.getElementById('addOvl').classList.remove('on');
  document.getElementById('addCt').value = '';
  document.getElementById('addTm').value = '09:00';
  var bs = document.querySelectorAll('#tmQuick .tm-qbtn');
  bs.forEach(function(b){ b.classList.remove('sel'); });
}
function setQuickTm(tm, btn) {
  document.getElementById('addTm').value = tm;
  var bs = document.querySelectorAll('#tmQuick .tm-qbtn');
  bs.forEach(function(b){ b.classList.remove('sel'); });
  btn.classList.add('sel');
}
function setAddTg(tag, btn) {
  _addTag = tag;
  var bs = document.querySelectorAll('#addTgs .add-tbtn');
  bs.forEach(function(b){ b.classList.toggle('sel', b===btn); });
}
function doAdd() {
  var ct = document.getElementById('addCt').value.trim();
  if (!ct) return;
  var tm = document.getElementById('addTm').value;
  if (!events[selectedDate]) events[selectedDate] = [];
  events[selectedDate].push({ time:tm, content:ct, tag:_addTag, done:false });
  saveEvents();
  closeAddPanel();
  renderAll();
}

// ===== Voice =====
function toggleMic() {
  if (isRecording) { stopRec(); return; }
  if (!window.SpeechRecognitionAPI) {
    document.getElementById('addVoiceRes').textContent = '语音不可用';
    document.getElementById('addVoiceRes').style.color = '#ef4444';
    return;
  }
  try {
    recognition = new SpeechRecognitionAPI();
    recognition.lang = 'zh-CN';
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.onresult = function(ev) {
      var txt = ev.results[0][0].transcript;
      document.getElementById('addCt').value = txt;
      document.getElementById('addVoiceRes').textContent = '已识别: ' + txt;
      document.getElementById('addVoiceRes').style.color = 'var(--pri)';
    };
    recognition.onerror = function(ev) {
      document.getElementById('addVoiceRes').textContent = '识别失败: ' + ev.error;
      document.getElementById('addVoiceRes').style.color = '#ef4444';
      stopRec();
    };
    recognition.onend = function() { stopRec(); };
    recognition.start();
    isRecording = true;
    document.getElementById('addMicBtn').classList.add('rec');
  } catch(e) {
    document.getElementById('addVoiceRes').textContent = '启动失败';
    document.getElementById('addVoiceRes').style.color = '#ef4444';
  }
}
function stopRec() {
  if (recognition) { try { recognition.stop(); } catch(e) {} }
  isRecording = false;
  document.getElementById('addMicBtn').classList.remove('rec');
}

// ==================== 设置面板（数据操作） ====================
// ===== Settings =====
function toggleSettings() {
  var p = document.getElementById('setPnl');
  var o = document.getElementById('setOvl');
  if (p.classList.contains('on')) { closeSettings(); }
  else { p.classList.add('on'); o.classList.add('on'); }
}
function closeSettings() {
  document.getElementById('setPnl').classList.remove('on');
  document.getElementById('setOvl').classList.remove('on');
}
function doExport() {
  var data = JSON.stringify(events, null, 2);
  var blob = new Blob([data], {type:'application/json'});
  var url = URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url; a.download = 'pixel_planner_backup_'+todayKey+'.json';
  a.click(); URL.revokeObjectURL(url);
  closeSettings();
}
function doImport(ev) {
  var f = ev.target.files[0];
  if (!f) return;
  var r = new FileReader();
  r.onload = function(e) {
    try {
      var data = JSON.parse(e.target.result);
      if (typeof data === 'object') { events = data; saveEvents(); renderAll(); alert('导入成功！'); closeSettings(); }
      else { alert('无效格式'); }
    } catch(ex) { alert('解析失败: '+ex.message); }
  };
  r.readAsText(f);
  ev.target.value = '';
}
function doChkUpdate() {
  // Use original showUpdateDialog if available
  if (typeof showUpdateDialog === 'function') { showUpdateDialog(); }
  else { alert('更新检查: 当前版本 v3.0'); }
  closeSettings();
}
function doClearAll() {
  if (confirm('此操作不可撤销！确认清除所有数据？')) {
    events = {}; saveEvents(); renderAll(); closeSettings();
  }
}
