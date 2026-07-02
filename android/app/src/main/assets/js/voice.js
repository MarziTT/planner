// 语程 — 语音交互模块 v4.6
// Android：AudioRecord 原生录音 → base64 WAV → POST /api/asr → 腾讯云 ASR
// 桌面/鸿蒙：getUserMedia 录音 → POST /api/asr → 后端代理签名

var voiceResultText = '';
var mediaRecorder = null;
var audioChunks = [];
var voiceRecTimer = null;

// ── 平台检测 ──
var OHOS = /OpenHarmony|HarmonyOS/i.test(navigator.userAgent);
var ANDROID = /Android/i.test(navigator.userAgent) && !OHOS;
document.documentElement.classList.add(OHOS ? 'ohos' : ANDROID ? 'android' : 'desktop');

// ── 引擎检测 ──
function getVoiceEngine() {
  var hasDirect = typeof AndroidBridge !== 'undefined'
               && typeof AndroidBridge.startDirectRecording === 'function';
  // Android：优先 AudioRecord 直接录音（可靠）
  if (ANDROID && hasDirect) return 'direct';
  // 桌面/鸿蒙：getUserMedia 录音
  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) return 'web';
  // Android 无原生桥：打字兜底
  if (ANDROID) return 'none';
  // 桌面备用
  if (hasDirect) return 'direct';
  return 'none';
}

// ── 入口 ──
function toggleVoiceZone() {
  var engine = getVoiceEngine();
  if (engine === 'direct') return toggleVoiceDirect();
  if (engine === 'web')    return toggleVoiceASR();
  return toggleVoiceFallback();
}

// ═══════════ Android AudioRecord 直接录音（v4.6 可靠方案）═══════════
function toggleVoiceDirect() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');

  if (voiceIsRecording) {
    clearTimeout(voiceRecTimer);
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '识别中...';
    AndroidBridge.stopDirectRecording();
    return;
  }

  voiceResultText = '';
  if (input) input.value = '';
  zone.classList.add('recording');
  voiceIsRecording = true;
  hint.textContent = '正在聆听...';
  AndroidBridge.startDirectRecording();
}

// Java 回调：录音开始
function onVoiceStart() {
  var hint = document.getElementById('voiceHint');
  if (hint) hint.textContent = '正在聆听...';
}

// Java 回调：录音完成，传入 base64 WAV
function onVoiceAudio(b64) {
  voiceIsRecording = false;
  clearTimeout(voiceRecTimer);
  var zone = document.getElementById('voiceZone');
  if (zone) zone.classList.remove('recording');
  var hint = document.getElementById('voiceHint');
  if (hint) hint.textContent = '识别中...';

  // 构造 Blob 发送到 Railway ASR
  var raw = atob(b64);
  var bytes = new Uint8Array(raw.length);
  for (var i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  var blob = new Blob([bytes], { type: 'audio/wav' });
  sendToASR(blob);
}

// Java 回调：识别错误
function onVoiceError(msg) {
  voiceIsRecording = false;
  clearTimeout(voiceRecTimer);
  var zone = document.getElementById('voiceZone');
  if (zone) zone.classList.remove('recording');
  var hint = document.getElementById('voiceHint');
  if (hint) hint.textContent = msg || '识别失败';
}

// ═══════════ 桌面/鸿蒙 getUserMedia 录音 ═══════════
function toggleVoiceASR() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');

  if (voiceIsRecording) {
    clearTimeout(voiceRecTimer);
    stopASRRecording();
    return;
  }

  voiceResultText = '';
  if (input) input.value = '';
  audioChunks = [];

  navigator.mediaDevices.getUserMedia({ audio: true })
    .then(function (stream) {
      var opts = {};
      if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        opts.mimeType = 'audio/webm;codecs=opus';
      }

      mediaRecorder = new MediaRecorder(stream, opts);
      mediaRecorder.ondataavailable = function (e) {
        if (e.data && e.data.size > 0) audioChunks.push(e.data);
      };

      mediaRecorder.onstop = function () {
        stream.getTracks().forEach(function (t) { t.stop(); });
        if (audioChunks.length === 0) {
          hint.textContent = '未录制到音频';
          voiceIsRecording = false;
          zone.classList.remove('recording');
          return;
        }
        var blob = new Blob(audioChunks, { type: mediaRecorder.mimeType || 'audio/webm' });
        hint.textContent = '识别中...';
        sendToASR(blob);
      };

      mediaRecorder.start(100);
      zone.classList.add('recording');
      voiceIsRecording = true;
      hint.textContent = '正在聆听...';

      voiceRecTimer = setTimeout(function () {
        if (voiceIsRecording) stopASRRecording();
      }, 15000);
    })
    .catch(function (err) {
      hint.textContent = '麦克风权限被拒绝';
      voiceIsRecording = false;
    });
}

function stopASRRecording() {
  if (mediaRecorder && mediaRecorder.state === 'recording') {
    mediaRecorder.stop();
  }
  var zone = document.getElementById('voiceZone');
  if (zone) zone.classList.remove('recording');
  voiceIsRecording = false;
  clearTimeout(voiceRecTimer);
}

// ═══════════ ASR 请求 ═══════════
var ASR_SERVER = 'https://planner-production-d1ee.up.railway.app';

function getASRUrl() {
  if (typeof AndroidBridge !== 'undefined' && typeof AndroidBridge.getServerUrl === 'function') {
    var url = AndroidBridge.getServerUrl();
    if (url) return url + '/api/asr';
  }
  return ASR_SERVER + '/api/asr';
}

function sendToASR(blob) {
  var xhr = new XMLHttpRequest();
  xhr.open('POST', getASRUrl(), true);
  xhr.setRequestHeader('Content-Type', blob.type || 'audio/wav');
  xhr.timeout = 30000;
  xhr.responseType = 'json';

  xhr.onload = function () {
    var hint = document.getElementById('voiceHint');
    var input = document.getElementById('voiceTextInput');
    if (!hint) return;

    if (xhr.status === 200 && xhr.response && xhr.response.ok) {
      var text = xhr.response.text || '';
      voiceResultText = text;
      hint.textContent = text || '（未识别到内容）';
      if (input) input.value = text;
      if (text) submitVoiceText();
    } else {
      var errMsg = (xhr.response && xhr.response.error) ? xhr.response.error : '识别失败';
      hint.textContent = errMsg;
    }
  };

  xhr.onerror = function () {
    var hint = document.getElementById('voiceHint');
    if (hint) hint.textContent = '网络错误，请重试';
  };

  xhr.ontimeout = function () {
    var hint = document.getElementById('voiceHint');
    if (hint) hint.textContent = '识别超时，请重试';
  };

  xhr.send(blob);
}

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

// 解析相对日期偏移量（明天、后天、大后天、下周X 等）
function parseRelativeDate(text) {
  var now = new Date();
  // 今天：偏移0，但默认用 selectedDate 对应的日期
  var todayDate = new Date();
  var baseDate = selectedDate ? new Date(selectedDate + 'T00:00:00') : new Date();
  // 如果 selectedDate 不是今天（用户在看其他日期），则基于 selectedDate
  var useSelected = (selectedDate && selectedDate !== todayKey && selectedDate !== dateKey(todayDate));

  // 绝对日期词：今天、明天、后天、大后天
  if (/今天|今日/.test(text)) {
    return { offset: 0, label: '今天', base: useSelected ? new Date(selectedDate + 'T00:00:00') : new Date() };
  }
  if (/明天|明日/.test(text)) {
    var d = new Date(); d.setDate(d.getDate() + 1);
    return { offset: 1, label: '明天', base: d };
  }
  if (/后天|后日/.test(text)) {
    var d = new Date(); d.setDate(d.getDate() + 2);
    return { offset: 2, label: '后天', base: d };
  }
  if (/大后天/.test(text)) {
    var d = new Date(); d.setDate(d.getDate() + 3);
    return { offset: 3, label: '大后天', base: d };
  }
  if (/大后天后天/.test(text)) {
    var d = new Date(); d.setDate(d.getDate() + 4);
    return { offset: 4, label: '大后天后天', base: d };
  }

  // 下周X / 下周一 等
  var weekMap = { '一':1, '二':2, '三':3, '四':4, '五':5, '六':6, '天':0, '日':0, '周日':0 };
  var nw = text.match(/下周\s*([一二三四五六天日])/);
  if (nw) {
    var targetDay = weekMap[nw[1]];
    var curDay = now.getDay();
    var diff = (7 - curDay + targetDay) % 7;
    if (diff === 0) diff = 7; // 下周同一天 = 7天后
    var d = new Date(); d.setDate(d.getDate() + diff);
    return { offset: diff, label: '下周' + nw[1], base: d };
  }
  // 下下周X
  var nnw = text.match(/下下周\s*([一二三四五六天日])/);
  if (nnw) {
    var td2 = weekMap[nnw[1]];
    var cd2 = now.getDay();
    var diff2 = (14 - cd2 + td2) % 14;
    if (diff2 === 0) diff2 = 14;
    var d = new Date(); d.setDate(d.getDate() + diff2);
    return { offset: diff2, label: '下下周' + nnw[1], base: d };
  }
  // 这周X（本周）
  var tw = text.match(/这周\s*([一二三四五六天日])/);
  if (tw) {
    var td3 = weekMap[tw[1]];
    var cd3 = now.getDay();
    var diff3 = (td3 - cd3 + 7) % 7;
    var d = new Date(); d.setDate(d.getDate() + diff3);
    return { offset: diff3, label: '本周' + tw[1], base: d };
  }

  return null;
}

function parseChineseTime(text) {
  var cnDigits = { '零':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9,
                   '十':10,'十一':11,'十二':12,'十三':13,'十四':14,'十五':15 };
  var perMap = { '早上':0,'早晨':0,'凌晨':0,'上午':0,'中午':12,'下午':12,'傍晚':12,'晚上':12,'夜里':12,'夜间':12 };

  // 先解析相对日期
  var relDate = parseRelativeDate(text);

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
    var result = { time: S(h) + ':' + S(min), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
    if (relDate) { result.date = dateKey(relDate.base); result.dateLabel = relDate.label; }
    return result;
  }
  m = text.match(/(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var h2 = cnDigits[m[2]], min2 = m[4] ? (cnDigits[m[4]] || 0) : (m[2] ? 30 : 0);
    if (isNaN(h2)) return null;
    h2 = applyPeriod(m[1], h2);
    var result = { time: S(h2) + ':' + S(min2), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
    if (relDate) { result.date = dateKey(relDate.base); result.dateLabel = relDate.label; }
    return result;
  }
  m = text.match(/(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/);
  if (m) {
    var h3 = parseInt(m[1]), min3 = m[3] ? parseInt(m[3]) : (m[2] ? 30 : 0);
    var ampm = inferAmPm(h3, text);
    if (ampm === 'pm' && h3 < 12) h3 += 12;
    if (ampm === 'am' && h3 === 12) h3 = 0;
    var result = { time: S(h3) + ':' + S(min3), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
    if (relDate) { result.date = dateKey(relDate.base); result.dateLabel = relDate.label; }
    return result;
  }
  m = text.match(/([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var h4 = cnDigits[m[1]], min4 = m[3] ? (cnDigits[m[3]] || 0) : (m[2] ? 30 : 0);
    if (isNaN(h4)) return null;
    var ampm2 = inferAmPm(h4, text);
    if (ampm2 === 'pm' && h4 < 12) h4 += 12;
    if (ampm2 === 'am' && h4 === 12) h4 = 0;
    var result = { time: S(h4) + ':' + S(min4), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
    if (relDate) { result.date = dateKey(relDate.base); result.dateLabel = relDate.label; }
    return result;
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

  // 尝试从原始语音文本中解析日期
  var rawText = (document.getElementById('voiceTextInput') || {}).value || title;
  var parsed = parseChineseTime(rawText);
  var targetDate = (parsed && parsed.date) ? parsed.date : selectedDate;
  var dateLabel = (parsed && parsed.dateLabel) ? ' (' + parsed.dateLabel + ')' : '';

  if (!events[targetDate]) events[targetDate] = [];
  events[targetDate].push({ time: time || (parsed ? parsed.time : '09:00'), content: title, tag: tag, done: false });
  saveEvents();
  closeVoiceConfirm();
  document.getElementById('cfmVoiceTitle').value = '';
  var all = document.querySelectorAll('#cfmVoiceTags .tag-chip');
  for (var j = 0; j < all.length; j++) all[j].classList.remove('selected');
  if (all.length > 0) all[0].classList.add('selected');
  // 如果日期变了，更新选中日期
  if (targetDate !== selectedDate) {
    selectedDate = targetDate;
    var dp = targetDate.split('-');
    if (dp.length === 3) { pnlY = parseInt(dp[0]); pnlM = parseInt(dp[1]); }
  }
  renderAll();
  if (typeof showToast === 'function') showToast('已添加到 ' + targetDate + dateLabel);
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
