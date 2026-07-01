// 语程 — 语音交互模块 v4.1
// 双引擎：Web Speech API（优先）+ 原生 AndroidBridge（兜底）
// 兼容 Android WebView / 鸿蒙 ArkWeb / Chrome / Edge

var voiceResultText = '';
var recognition = null;
var voiceRecTimer = null;
var silenceTimer = null;

// ── 平台检测 ──
var OHOS = /OpenHarmony|HarmonyOS/i.test(navigator.userAgent);
var ANDROID = /Android/i.test(navigator.userAgent) && !OHOS;
document.documentElement.classList.add(OHOS ? 'ohos' : ANDROID ? 'android' : 'desktop');

// ── 引擎检测 ──
function getVoiceEngine() {
  var SRec = window.SpeechRecognition || window.webkitSpeechRecognition;
  var hasNative = typeof AndroidBridge !== 'undefined'
               && typeof AndroidBridge.startVoiceRecognition === 'function';
  if (SRec) return 'web';
  if (hasNative) return 'native';
  return 'none';
}

// ── 入口 ──
function toggleVoiceZone() {
  var engine = getVoiceEngine();
  if (engine === 'web')  return toggleVoiceWeb();
  if (engine === 'native') return toggleVoiceNative();
  return toggleVoiceFallback();
}

// ═══════════ Web Speech API ═══════════
function toggleVoiceWeb() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');
  var SRec = window.SpeechRecognition || window.webkitSpeechRecognition;

  if (voiceIsRecording) {
    clearTimeout(voiceRecTimer); clearTimeout(silenceTimer);
    if (recognition) { try { recognition.stop(); } catch (_) {} recognition = null; }
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '点击开始语音记录';
    var text = voiceResultText || (input ? input.value.trim() : '');
    if (text) { voiceResultText = text; if (input) input.value = text; submitVoiceText(); }
    return;
  }

  voiceResultText = '';
  if (input) input.value = '';

  recognition = new SRec();
  recognition.continuous = true;
  recognition.interimResults = true;
  recognition.lang = 'zh-CN';

  recognition.onstart = function () {
    zone.classList.add('recording');
    voiceIsRecording = true;
    hint.textContent = '正在聆听...';
  };

  recognition.onresult = function (event) {
    var interim = '', finalText = '';
    for (var i = event.resultIndex; i < event.results.length; i++) {
      var t = event.results[i][0].transcript;
      if (event.results[i].isFinal) finalText += t; else interim += t;
    }
    var display = finalText || interim;
    if (display) {
      hint.textContent = display;
      voiceResultText = finalText || display;
      if (input) input.value = display;
    }
    clearTimeout(silenceTimer);
    if (display && !finalText) {
      silenceTimer = setTimeout(function () {
        if (recognition && voiceIsRecording) { try { recognition.stop(); } catch (_) {} }
      }, 2500);
    }
  };

  recognition.onerror = function (event) {
    clearTimeout(voiceRecTimer); clearTimeout(silenceTimer);
    voiceIsRecording = false; zone.classList.remove('recording'); recognition = null;
    var map = {
      'not-allowed': '麦克风权限被拒绝',
      'no-speech': '未检测到语音', 'aborted': '已取消',
      'audio-capture': '麦克风不可用', 'network': '网络错误'
    };
    var msg = map[event.error] || ('异常: ' + event.error);
    hint.textContent = msg;
    if (input) input.value = msg;
  };

  recognition.onend = function () {
    clearTimeout(silenceTimer);
    if (!voiceIsRecording) return;
    voiceIsRecording = false; zone.classList.remove('recording'); recognition = null;
    hint.textContent = voiceResultText ? '已识别，点击确认 ▸' : '点击开始语音记录';
  };

  try { recognition.start(); } catch (e) {
    hint.textContent = '启动失败: ' + e.message; recognition = null;
  }
  voiceRecTimer = setTimeout(function () {
    if (recognition && voiceIsRecording) { try { recognition.stop(); } catch (_) {} recognition = null; toggleVoiceZone(); }
  }, 30000);
}

// ═══════════ 原生 Android SpeechRecognizer ═══════════
function toggleVoiceNative() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');

  if (voiceIsRecording) {
    clearTimeout(voiceRecTimer);
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '点击开始语音记录';
    if (AndroidBridge.stopVoiceRecognition) AndroidBridge.stopVoiceRecognition();
    if (voiceResultText) { if (input) input.value = voiceResultText; submitVoiceText(); }
    return;
  }

  voiceResultText = '';
  if (input) input.value = '';
  zone.classList.add('recording');
  voiceIsRecording = true;
  hint.textContent = '正在聆听...';
  AndroidBridge.startVoiceRecognition();
  voiceRecTimer = setTimeout(function () { toggleVoiceZone(); }, 8000);
}

// Android 原生回调（由 evaluateJavascript 触发）
function onVoiceResult(text)   { voiceResultText = text; var i = document.getElementById('voiceTextInput'); if (i) i.value = text; }
function onVoicePartial(text)  { var h = document.getElementById('voiceHint'); if (h) h.textContent = text; }
function onVoiceError(msg)     {
  voiceIsRecording = false; clearTimeout(voiceRecTimer);
  var z = document.getElementById('voiceZone'); if (z) z.classList.remove('recording');
  var h = document.getElementById('voiceHint'); if (h) h.textContent = msg || '识别失败';
  var i = document.getElementById('voiceTextInput'); if (i) i.value = msg || '识别失败';
}
function onVoicePermissionGranted() { if (AndroidBridge && AndroidBridge.startVoiceRecognition) AndroidBridge.startVoiceRecognition(); }

// ═══════════ 无引擎兜底 ═══════════
function toggleVoiceFallback() {
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');
  hint.textContent = '语音不可用，请在下方打字输入';
  if (input) { input.value = ''; input.focus(); }
}

// ═══════════ 提交文本 ═══════════
function submitVoiceText() {
  var text = voiceResultText || '';
  if (!text) { var input = document.getElementById('voiceTextInput'); text = input ? input.value.trim() : ''; }
  if (!text) return;

  var parsed = parseChineseTime(text);
  if (parsed) {
    document.getElementById('cfmVoiceTime').value = parsed.time;
    document.getElementById('cfmVoiceTitle').value = parsed.title;
  } else {
    var tm = text.match(/(\d{1,2}[:：]\d{2})/);
    if (tm) {
      document.getElementById('cfmVoiceTime').value = tm[1].replace('：', ':');
      document.getElementById('cfmVoiceTitle').value = text.replace(tm[0], '').trim();
    } else {
      document.getElementById('cfmVoiceTitle').value = text;
    }
  }
  document.getElementById('voiceTextInput').value = '';
  showVoiceConfirm();
}

// ═══════════ 中文时间解析 ═══════════
function inferAmPm(h, text) {
  if (/下班|晚饭|晚餐|晚上/.test(text)) return 'pm';
  if (/上班|早|晨/.test(text)) return 'am';
  if (h >= 8 && h <= 11) return 'am';
  if ((h >= 1 && h <= 6) || h === 12) return 'pm';
  return 'am';
}

function parseChineseTime(text) {
  var cnDigits = { '零':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9,
                   '十':10,'十一':11,'十二':12,'十三':13,'十四':14,'十五':15 };
  var perMap = { '早上':0,'早晨':0,'凌晨':0,'上午':0,'中午':12,'下午':12,'傍晚':12,'晚上':12,'夜里':12,'夜间':12 };

  function applyPeriod(period, h) {
    if (period === '中午' && h === 12) return 12;
    if (period === '中午' && h < 12) return h + 12;
    if (period === '下午' && h === 12) return 12;
    var v = h + (perMap[period] || 0);
    if ((period === '凌晨' || period === '早上' || period === '早晨') && v === 12) return 0;
    return v % 24;
  }

  var re = /(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/;
  var m = text.match(re);
  if (m) {
    var h = parseInt(m[2]), min = m[4] ? parseInt(m[4]) : (m[3] ? 30 : 0);
    h = applyPeriod(m[1], h);
    return { time: S(h) + ':' + S(min), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }
  m = text.match(/(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var h2 = cnDigits[m[2]], min2 = m[4] ? (cnDigits[m[4]] || 0) : (m[3] ? 30 : 0);
    if (isNaN(h2)) return null;
    h2 = applyPeriod(m[1], h2);
    return { time: S(h2) + ':' + S(min2), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }
  m = text.match(/(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/);
  if (m) {
    var h3 = parseInt(m[1]), min3 = m[3] ? parseInt(m[3]) : (m[2] ? 30 : 0);
    var ampm = inferAmPm(h3, text);
    if (ampm === 'pm' && h3 < 12) h3 += 12;
    if (ampm === 'am' && h3 === 12) h3 = 0;
    return { time: S(h3) + ':' + S(min3), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }
  m = text.match(/([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var h4 = cnDigits[m[1]], min4 = m[3] ? (cnDigits[m[3]] || 0) : (m[2] ? 30 : 0);
    if (isNaN(h4)) return null;
    var ampm2 = inferAmPm(h4, text);
    if (ampm2 === 'pm' && h4 < 12) h4 += 12;
    if (ampm2 === 'am' && h4 === 12) h4 = 0;
    return { time: S(h4) + ':' + S(min4), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }
  return null;
}
function S(n) { return String(n).padStart(2, '0'); }

// ═══════════ 确认卡片 ═══════════
function showVoiceConfirm() {
  document.getElementById('confirmVoiceOverlay').classList.add('active');
  var container = document.getElementById('cfmVoiceTags');
  var tags = (typeof getDynamicTags === 'function') ? getDynamicTags() : [
    { name: '工作', color: '#4A90D9' }, { name: '学习', color: '#50C878' }, { name: '生活', color: '#F5A623' }
  ];
  var title = (document.getElementById('cfmVoiceTitle') || {}).value || '';
  var sug = (typeof classifyVoiceText === 'function') ? classifyVoiceText(title) : null;
  var html = '';
  for (var i = 0; i < tags.length; i++) {
    html += '<button class="tag-chip' + (sug === tags[i].name || (!sug && i === 0) ? ' selected' : '') + '" onclick="toggleVoiceTag(this)">' + tags[i].name + '</button>';
  }
  container.innerHTML = html;
}
function closeVoiceConfirm() { document.getElementById('confirmVoiceOverlay').classList.remove('active'); }
function toggleVoiceTag(el) { el.classList.toggle('selected'); }

function confirmVoiceTask() {
  var time = document.getElementById('cfmVoiceTime').value;
  var title = document.getElementById('cfmVoiceTitle').value.trim();
  if (!title) return;
  var chips = document.querySelectorAll('#cfmVoiceTags .tag-chip.selected'), s = [];
  for (var i = 0; i < chips.length; i++) s.push(chips[i].textContent);
  var tag = s[0] || '工作';
  if (!events[selectedDate]) events[selectedDate] = [];
  events[selectedDate].push({ time: time || '09:00', content: title, tag: tag, done: false });
  saveEvents();
  closeVoiceConfirm();
  document.getElementById('cfmVoiceTitle').value = '';
  var all = document.querySelectorAll('#cfmVoiceTags .tag-chip');
  for (var j = 0; j < all.length; j++) all[j].classList.remove('selected');
  if (all.length > 0) all[0].classList.add('selected');
  renderAll();
  if (typeof showToast === 'function') showToast('已添加：' + title);
}

// ═══════════ 标签分类 ═══════════
function classifyVoiceText(text) {
  if (!text || typeof VOICE_TAG_RULES === 'undefined') return null;
  var lower = text.toLowerCase(), bestTag = null, bestScore = 0;
  for (var i = 0; i < VOICE_TAG_RULES.length; i++) {
    var score = 0;
    for (var j = 0; j < VOICE_TAG_RULES[i].keys.length; j++) {
      if (lower.indexOf(VOICE_TAG_RULES[i].keys[j]) !== -1) score++;
    }
    if (score > bestScore) { bestScore = score; bestTag = VOICE_TAG_RULES[i].tag; }
  }
  if (bestTag && bestScore > 0) {
    var tags = getDynamicTags(), exists = false;
    for (var k = 0; k < tags.length; k++) { if (tags[k].name === bestTag) { exists = true; break; } }
    if (!exists) {
      var colors = ['#4A90D9','#50C878','#F5A623','#E85D75','#9B59B6','#1ABC9C','#E67E22','#3498DB'];
      tags.push({ name: bestTag, color: colors[tags.length % colors.length], emoji: '🏷️' });
      saveDynamicTags(tags);
      syncAllTags();
    }
    return bestTag;
  }
  return null;
}

// ═══════════ 事件绑定 ═══════════
(function initVoiceEvents() {
  if (window._voiceEventsBound) return;
  window._voiceEventsBound = true;
  var ring = document.getElementById('voiceRing');
  if (ring) ring.addEventListener('click', function (e) { e.preventDefault(); toggleVoiceZone(); });
  var btn = document.getElementById('voiceSubmitBtn');
  if (btn) btn.addEventListener('click', function (e) { e.preventDefault(); submitVoiceText(); });
  var input = document.getElementById('voiceTextInput');
  if (input) input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); submitVoiceText(); }
  });
})();
