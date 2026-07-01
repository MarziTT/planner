// 语程 — 应用入口与初始化
// 职责: DOMContentLoaded初始化、事件绑定、键盘处理、动态标签系统、Toast、SQLite数据初始化

// ==================== 键盘事件 ====================
// ===== Keyboard =====
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    if (document.getElementById('addPanel').classList.contains('on')) closeAddPanel();
    else if (document.getElementById('calPnl').classList.contains('on')) closeCalendar();
    else if (document.getElementById('setPnl').classList.contains('on')) closeSettings();
    else if (_editIdx >= 0) cancelEdit();
  }
});


// ==================== 热更新提示 ====================
(function checkHotUpdate() {
  var m = location.search.match(/[?&]huver=([^&]+)/);
  if (m) {
    var ver = decodeURIComponent(m[1]);
    var prevVer = localStorage.getItem('_last_huver');
    if (prevVer !== ver) {
      localStorage.setItem('_last_huver', ver);
      showToast('已更新至 v' + ver + ' — 前端资源已热更新，无需重装');
    }
  }
})();

// ==================== initApp ====================
// ===== initApp =====
(function initApp() {
  updateDt();
  updClock();
  setInterval(updClock, 1000);
  renderAll();

  // Override original addEvent to open add panel
  if (typeof addEvent === 'function') {
    var _origAddEvent = addEvent;
    addEvent = function() { openAddPanel(); };
  }

  // Override render for compatibility
  var _origRender = (typeof render === 'function') ? render : null;
  render = function() {
    renderAll();
  };

  // Override renderEvents
  var _origRenderEvents = (typeof renderEvents === 'function') ? renderEvents : null;
  renderEvents = function() { renderAll(); };

  // Override deleteEvent
  if (typeof deleteEvent === 'function') {
    var _origDeleteEvent = deleteEvent;
    deleteEvent = function(idx) { delEvt(idx); };
  }

  // Daily refresh
  setInterval(function() {
    var nt = dk(new Date());
    if (nt !== todayKey) {
      todayKey = nt;
      selectedDate = nt;
      updateDt();
      renderAll();
    }
  }, 60000);
})();


// ================================================================
// Pixel Planner v3.1 — Auth, Dynamic Tags, Voice AI, Questionnaire
// ================================================================


// ===== Voice Zone (v3.3) =====
var voiceIsRecording = false;
var voiceRecTimer = null;

function randomGif() {
  var paths = ["gifs/1号.gif","gifs/2号.gif","gifs/3号.gif","gifs/4号.gif","gifs/5号.gif","gifs/6号.gif","gifs/7号.gif","gifs/8号.gif","gifs/9号.gif","gifs/10号.gif","gifs/11号.gif","gifs/12号.gif","gifs/13.gif","gifs/14.gif","gifs/15.gif","gifs/16.gif","gifs/17.gif","gifs/18.gif","gifs/19.gif","gifs/21.gif","gifs/22.gif","gifs/23.gif","gifs/24.gif","gifs/25.gif","gifs/26.gif","gifs/27.gif","gifs/28.gif","gifs/29.gif","gifs/30.gif","gifs/31.gif","gifs/32.gif","gifs/33.gif","gifs/34.gif","gifs/35.gif","gifs/36.gif","gifs/37.gif","gifs/38.gif","gifs/39.gif","gifs/40.gif","gifs/41.gif","gifs/42.gif","gifs/43.gif","gifs/惩戒秩序.gif","gifs/等离子.gif","gifs/重力.gif","gifs/奇异.gif","gifs/护盾.gif","gifs/恢复.gif","gifs/分身.gif","gifs/器械.gif","gifs/雨天.gif","gifs/飞行.gif","gifs/变换.gif","gifs/冲击.gif","gifs/20.gif"];
  return paths[Math.floor(Math.random() * paths.length)];
}

function gifBgHtml() {
  if (document.documentElement.getAttribute('data-theme') !== 'kamen') return '';
  return '<img class="card-gif-bg" src="'+randomGif()+'" alt="">';
}


// ================================================================
// Pixel Planner v3.1 — Auth, Dynamic Tags, Voice AI, Questionnaire
// ================================================================

// ==================== 动态标签系统 ====================
// ====== 3. DYNAMIC TAG SYSTEM ======
var TAGS_STORAGE_KEY = 'pixel_dynamic_tags';

function getDynamicTags() {
  // [v3.2 SQLite] tags loaded from DB via initDataFromServer()
  // Fall back to defaults, server data is loaded asynchronously
  return getDefaultTags();
}

function getDefaultTags() {
  return [
    { name: '工作', color: '#4A90D9', emoji: '💼' },
    { name: '学习', color: '#50C878', emoji: '📚' },
    { name: '生活', color: '#F5A623', emoji: '🏠' }
  ];
}

async function saveDynamicTags(tags) {
  try {
    await apiCall('POST', '/api/tags/sync', { tags: tags });
  } catch(e) {
    console.warn('saveDynamicTags failed:', e);
  }
}

// Initialize tags on load
(function initDynamicTags() {
  // [v3.2 SQLite] tags initialized from server via initDataFromServer()
  // Default tags will be created on server if needed
})();

// Default tag CSS class mapping
var DEFAULT_TAG_CLASSES = { '工作':'tg-w', '学习':'tg-s', '生活':'tg-l' };

// Sync ALL_TAGS for compatibility with original code
function syncAllTags() {
  var tags = getDynamicTags();
  ALL_TAGS = tags.map(function(t){ return t.name; });
  // Rebuild TAG_COLORS — preserve original class names for defaults
  var tc = {};
  var styleRules = [];
  for (var i = 0; i < tags.length; i++) {
    var t = tags[i];
    if (DEFAULT_TAG_CLASSES[t.name]) {
      tc[t.name] = DEFAULT_TAG_CLASSES[t.name];
    } else {
      var clsName = 'tg-dyn-' + i;
      tc[t.name] = clsName;
      styleRules.push('.' + clsName + ' { background:' + t.color + ' !important; color:#fff !important; }');
    }
  }
  TAG_COLORS = tc;
  // Inject dynamic tag styles
  var styleEl = document.getElementById('dynTagStyles');
  if (!styleEl) {
    styleEl = document.createElement('style');
    styleEl.id = 'dynTagStyles';
    document.head.appendChild(styleEl);
  }
  styleEl.textContent = styleRules.join('\n');
}

// Called on app start
syncAllTags();

// Override setAddTg to work with dynamic tag chips
var _origSetAddTg = typeof setAddTg === 'function' ? setAddTg : null;
setAddTg = function(tag, btn) {
  _addTag = tag;
  var chips = document.querySelectorAll('#addTgs .add-tag-chip, #addTgs .add-tbtn');
  for (var i = 0; i < chips.length; i++) {
    chips[i].classList.toggle('sel', chips[i] === btn);
  }
};

// Override renderAddTags to use dynamic tags
var _origRenderAddTags = typeof renderAddTags === 'function' ? renderAddTags : null;

renderAddTags = function() {
  var tags = getDynamicTags();
  var selectedTag = _addTag || '';
  var html = '';
  for (var i = 0; i < tags.length; i++) {
    var t = tags[i];
    var sel = (selectedTag === t.name) ? ' sel' : '';
    html += '<div class="add-tag-chip' + sel + '" style="background:' + t.color + ';color:#fff;" onclick="setAddTg(\'' + t.name.replace(/'/g,"\\'") + '\', this)">' + (t.emoji || '') + ' ' + t.name + '</div>';
  }
  html += '<div class="add-tag-plus" onclick="openTagPicker()">+</div>';
  var tgEl = document.getElementById('addTgs');
  if (tgEl) tgEl.innerHTML = html;
};

// Override openAddPanel to refresh tags
var _origOpenAddPanel = typeof openAddPanel === 'function' ? openAddPanel : null;

openAddPanel = function() {
  syncAllTags();
  // Ensure _addTag exists in current tags
  var tags = getDynamicTags();
  var tagNames = tags.map(function(t){ return t.name; });
  if (tagNames.indexOf(_addTag) === -1) {
    _addTag = tagNames[0] || '工作';
  }
  if (_origOpenAddPanel) _origOpenAddPanel();
  // Refresh tag chips after panel opens
  setTimeout(function(){
    if (typeof renderAddTags === 'function') renderAddTags();
  }, 50);
};

// ==================== 标签选择器面板 ====================
// ====== 4. TAG PICKER PANEL ======
function openTagPicker() {
  var tags = getDynamicTags();
  var selectedTag = _addTag || '';
  var html = '';
  for (var i = 0; i < tags.length; i++) {
    var t = tags[i];
    var sel = (selectedTag === t.name) ? ' sel' : '';
    html += '<div class="tag-pick-chip' + sel + '" style="border-color:' + t.color + ';" data-tag="' + t.name.replace(/"/g,'&quot;') + '" onclick="pickTagFromList(\'' + t.name.replace(/'/g,"\\'") + '\', this)">' + (t.emoji || '') + ' ' + t.name + '</div>';
  }
  document.getElementById('tagPickList').innerHTML = html;
  document.getElementById('tagPickNewName').value = '';
  document.getElementById('tagPickNewEmoji').value = '';
  document.getElementById('tagPickOverlay').classList.add('show');
}

function closeTagPicker() {
  document.getElementById('tagPickOverlay').classList.remove('show');
}

function pickTagFromList(tagName, el) {
  // Toggle selection
  var chips = document.querySelectorAll('#tagPickList .tag-pick-chip');
  for (var i = 0; i < chips.length; i++) chips[i].classList.remove('sel');
  el.classList.add('sel');
  // Also create new tag if name is in the input
  var newName = document.getElementById('tagPickNewName').value.trim();
  if (newName) {
    addNewTagFromPicker();
  }
  // Store selection for confirm
  document.getElementById('tagPickOverlay').setAttribute('data-picked', tagName);
}

function confirmTagPick() {
  // Check if a new tag was entered
  var newName = document.getElementById('tagPickNewName').value.trim();
  var pickedFromList = document.getElementById('tagPickOverlay').getAttribute('data-picked') || '';

  if (newName) {
    // Create new tag
    var newEmoji = document.getElementById('tagPickNewEmoji').value.trim() || '📌';
    var newColor = document.getElementById('tagPickNewColor').value;
    var tags = getDynamicTags();
    tags.push({ name: newName, color: newColor, emoji: newEmoji });
    saveDynamicTags(tags);
    syncAllTags();
    pickedFromList = newName;
  }

  if (pickedFromList) {
    _addTag = pickedFromList;
    if (typeof renderAddTags === 'function') renderAddTags();
  }

  closeTagPicker();
}

function addNewTagFromPicker() {
  var newName = document.getElementById('tagPickNewName').value.trim();
  if (!newName) return;
  var tags = getDynamicTags();
  // Check if already exists
  for (var i = 0; i < tags.length; i++) {
    if (tags[i].name === newName) return;
  }
  var newEmoji = document.getElementById('tagPickNewEmoji').value.trim() || '📌';
  var newColor = document.getElementById('tagPickNewColor').value;
  tags.push({ name: newName, color: newColor, emoji: newEmoji });
  saveDynamicTags(tags);
  syncAllTags();
  // Refresh picker
  openTagPicker();
}

// ==================== 设置 - 标签管理 ====================
// ====== 6. SETTINGS — TAG MANAGEMENT ======
var _origToggleSettings = typeof toggleSettings === 'function' ? toggleSettings : null;

if (_origToggleSettings) {
  var origToggleSettings = toggleSettings;
  toggleSettings = function() {
    origToggleSettings();
    injectSettingsExtras();
  };
}

function injectSettingsExtras() {
  var panel = document.getElementById('setPnl');
  if (!panel) return;

  // Remove previous injections
  var existingUser = document.getElementById('settingsUserSection');
  if (existingUser) existingUser.remove();
  var existingTag = document.getElementById('settingsTagSection');
  if (existingTag) existingTag.remove();

  var user = getCurrentUser();

  // User section
  var userSection = document.createElement('div');
  userSection.id = 'settingsUserSection';
  userSection.className = 'set-sec';
  userSection.innerHTML = '<div class="set-sttl">账号</div>' +
    '<div style="padding:8px 14px;font-size:13px;color:var(--t2);margin-bottom:4px;">当前用户：' + (user || '未登录') + '</div>' +
    '<button class="set-btn" onclick="redoQuestionnaire();closeSettings();">重新填写身份问卷</button>' +
    '<button class="set-btn dng" onclick="doLogout()">退出登录</button>';
  panel.appendChild(userSection);

  // Tag management section
  var tagSection = document.createElement('div');
  tagSection.id = 'settingsTagSection';
  tagSection.className = 'set-sec';
  tagSection.innerHTML = '<div class="set-sttl">标签管理</div><div class="tag-mgmt" id="tagMgmtList"></div>' +
    '<button class="set-btn" onclick="addTagInSettings()" style="margin-top:8px;">+ 新建标签</button>';
  panel.appendChild(tagSection);

  renderTagMgmt();
}

function renderTagMgmt() {
  var container = document.getElementById('tagMgmtList');
  if (!container) return;
  var tags = getDynamicTags();
  var html = '';
  for (var i = 0; i < tags.length; i++) {
    var t = tags[i];
    html += '<div class="tag-mgmt-item">' +
      '<input class="tag-emoji-input" value="' + (t.emoji || '') + '" data-idx="' + i + '" data-field="emoji" onchange="updateTagField(' + i + ', \'emoji\', this.value)">' +
      '<input class="tag-name-input" value="' + t.name.replace(/"/g,'&quot;') + '" data-idx="' + i + '" data-field="name" onchange="updateTagField(' + i + ', \'name\', this.value)">' +
      '<input type="color" class="tag-color-select" value="' + t.color + '" data-idx="' + i + '" data-field="color" onchange="updateTagField(' + i + ', \'color\', this.value)">' +
      '<button class="tag-del-btn" onclick="deleteTagInSettings(' + i + ')" title="删除">×</button>' +
      '</div>';
  }
  container.innerHTML = html;
}

function updateTagField(idx, field, value) {
  var tags = getDynamicTags();
  if (idx >= 0 && idx < tags.length) {
    tags[idx][field] = value;
    saveDynamicTags(tags);
    syncAllTags();
    if (typeof renderAddTags === 'function') renderAddTags();
  }
}

function addTagInSettings() {
  var tags = getDynamicTags();
  var colors = ['#4A90D9','#50C878','#F5A623','#E85D75','#9B59B6','#1ABC9C','#E67E22'];
  tags.push({ name: '新标签', color: colors[tags.length % colors.length], emoji: '📌' });
  saveDynamicTags(tags);
  syncAllTags();
  renderTagMgmt();
  if (typeof renderAddTags === 'function') renderAddTags();
}

function deleteTagInSettings(idx) {
  var tags = getDynamicTags();
  if (tags.length <= 1) {
    showToast('至少保留一个标签');
    return;
  }
  tags.splice(idx, 1);
  saveDynamicTags(tags);
  syncAllTags();
  renderTagMgmt();
  if (typeof renderAddTags === 'function') renderAddTags();
}

function redoQuestionnaire() {
  document.getElementById('mainApp').style.display = 'none';
  showQuestionnaire();
}

// ==================== Toast ====================
// ====== 7. TOAST ======
var _toastTimer = null;
function showToast(msg) {
  var el = document.getElementById('toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  if (_toastTimer) clearTimeout(_toastTimer);
  _toastTimer = setTimeout(function(){
    el.classList.remove('show');
  }, 2000);
}

// ==================== 应用入口 ====================
// ====== 8. INIT — App Entry Gate ======
(function appEntry() {
  if (isLoggedIn()) {
    showMainApp();
    // Sync tags on load
    syncAllTags();
  } else {
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
  }
})();

// ==================== 钩子：doAdd后刷新标签 ====================
// ====== 9. Override doAdd to refresh tags ======
var _origDoAdd = typeof doAdd === 'function' ? doAdd : null;
if (_origDoAdd) {
  doAdd = function() {
    _origDoAdd();
    syncAllTags();
    if (typeof renderAddTags === 'function') {
      setTimeout(function(){ renderAddTags(); }, 50);
    }
  };
}

// ==================== 登录框回车键 ====================
// ====== 10. Enter key on login ======
(function() {
  var loginUser = document.getElementById('loginUser');
  var loginPw = document.getElementById('loginPw');
  var regConfirmPw = document.getElementById('regConfirmPw');
  if (loginPw) {
    loginPw.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') handleAuth();
    });
  }
  if (regConfirmPw) {
    regConfirmPw.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') handleAuth();
    });
  }
  if (loginUser) {
    loginUser.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') {
        if (loginPw) loginPw.focus();
      }
    });
  }
})();


// ==================== SQLite异步数据初始化 ====================
// ====== SQLite Async Data Initialization (v3.2) ======
async function initDataFromServer() {
  var uid = apiGetUser();
  if (!uid) return;

  try {
    // Load tags from server
    var serverTags = await apiGetTags();
    if (serverTags && serverTags.length > 0) {
      var tagList = [];
      for (var i = 0; i < serverTags.length; i++) {
        var st = serverTags[i];
        tagList.push({ id: st.id, name: st.name, color: st.color, emoji: st.emoji });
      }
      getDynamicTags.cache = tagList;
      getDynamicTags.cache._ts = Date.now();
      syncDynamicTagsToDOM(tagList);
    }

    // Load events from server — merge into events object
    var serverEvents = await apiGetEvents();
    if (serverEvents && serverEvents.length > 0) {
      serverEvents.forEach(function(ev) {
        if (!events[ev.date]) events[ev.date] = [];
        var exists = events[ev.date].some(function(e) { return e.id === ev.id; });
        if (!exists) {
          events[ev.date].push({
            id: ev.id,
            content: ev.title,
            time: ev.time,
            done: ev.completed || false,
            tag: (ev.tags && ev.tags.length > 0) ? ev.tags[0] : '工作',
            notes: ev.notes || ''
          });
        }
      });
    }
  } catch(err) {
    console.error('[initDataFromServer] Failed:', err);
  }

  if (typeof render === 'function') render();
}

function syncDynamicTagsToDOM(tagList) {
  if (typeof ALL_TAGS !== 'undefined') { ALL_TAGS = tagList; }
  tagList.forEach(function(t, idx) {
    var cls = '.tg-dyn-' + idx;
    if (!document.querySelector('style[data-dyn-tag="' + idx + '"]')) {
      var style = document.createElement('style');
      style.setAttribute('data-dyn-tag', idx);
      style.textContent = cls + ' { background: ' + t.color + '20; color: ' + t.color + '; } ' +
                          cls + '::before { background: ' + t.color + '; }';
      document.head.appendChild(style);
    }
  });
}

// Hook showMainApp to load data after login
var _origShowMainApp2 = typeof showMainApp === 'function' ? showMainApp : null;
if (typeof showMainApp !== 'undefined') {
  showMainApp = function() {
    if (_origShowMainApp2) _origShowMainApp2();
    setTimeout(function() { initDataFromServer(); }, 300);
  };
}
// ============================================
