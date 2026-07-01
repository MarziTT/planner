// 语程 — 语音交互模块 v4.0
// Web Speech API 驱动，兼容 Android WebView / 鸿蒙 ArkWeb / 桌面浏览器
// 内核：window.SpeechRecognition（或 webkitSpeechRecognition）
// 特性：连续识别、实时文字、静音自停、错误友好提示

var voiceResultText = '';
var recognition = null;
var voiceRecTimer = null;
var silenceTimer = null;

// ── 平台检测 ──
var OHOS = /OpenHarmony|HarmonyOS/i.test(navigator.userAgent);
var ANDROID = /Android/i.test(navigator.userAgent) && !OHOS;
document.documentElement.classList.add(OHOS ? 'ohos' : ANDROID ? 'android' : 'desktop');

// ── 入口：点击语音环 ──
function toggleVoiceZone() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');
  var SRec = window.SpeechRecognition || window.webkitSpeechRecognition;

  if (!SRec) {
    hint.textContent = '当前浏览器不支持语音识别';
    if (input) input.value = '请使用 Chrome / Edge / 鸿蒙浏览器';
    return;
  }

  if (voiceIsRecording) {
    // ── 手动停止 → 提交结果 ──
    clearTimeout(voiceRecTimer);
    clearTimeout(silenceTimer);
    if (recognition) {
      try { recognition.stop(); } catch (_) {}
      recognition = null;
    }
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '点击开始语音记录';

    var text = voiceResultText || (input ? input.value.trim() : '');
    if (text) {
      voiceResultText = text;
      if (input) input.value = text;
      submitVoiceText();
    }
  } else {
    // ── 开始识别 ──
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
        if (event.results[i].isFinal) { finalText += t; }
        else { interim += t; }
      }
      var display = finalText || interim;
      if (display) {
        hint.textContent = display;
        voiceResultText = finalText || display;
        if (input) input.value = display;
      }

      // 静音 2.5 秒后自动停止
      clearTimeout(silenceTimer);
      if (display && !finalText) {
        silenceTimer = setTimeout(function () {
          if (recognition && voiceIsRecording) {
            try { recognition.stop(); } catch (_) {}
          }
        }, 2500);
      }
    };

    recognition.onerror = function (event) {
      clearTimeout(voiceRecTimer); clearTimeout(silenceTimer);
      voiceIsRecording = false;
      zone.classList.remove('recording');
      recognition = null;
      var map = {
        'not-allowed': '麦克风权限被拒绝 — 请在系统设置中授权',
        'no-speech':   '未检测到语音',
        'aborted':     '识别已取消',
        'audio-capture': '麦克风不可用',
        'network':     '网络错误'
      };
      var msg = map[event.error] || ('识别异常: ' + event.error);
      hint.textContent = msg;
      if (input) input.value = msg;
    };

    recognition.onend = function () {
      clearTimeout(silenceTimer);
      if (!voiceIsRecording) return;
      voiceIsRecording = false;
      zone.classList.remove('recording');
      recognition = null;
      if (voiceResultText) {
        hint.textContent = '已识别，点击确认 ▸';
      } else {
        hint.textContent = '点击开始语音记录';
      }
    };

    try { recognition.start(); } catch (e) {
      hint.textContent = '启动失败: ' + e.message;
      recognition = null;
      return;
    }

    // 30 秒硬超时
    voiceRecTimer = setTimeout(function () {
      if (recognition && voiceIsRecording) {
        try { recognition.stop(); } catch (_) {}
        recognition = null;
        toggleVoiceZone();
      }
    }, 30000);
  }
}

// ── 提交文本 ──
function submitVoiceText() {
  var text = voiceResultText || '';
  if (!text) {
    var input = document.getElementById('voiceTextInput');
    text = input ? input.value.trim() : '';
  }
  if (!text) return;

  var parsed = parseChineseTime(text);
  if (parsed) {
    document.getElementById('cfmVoiceTime').value = parsed.time;
    document.getElementById('cfmVoiceTitle').value = parsed.title;
  } else {
    var timeMatch = text.match(/(\d{1,2}[:：]\d{2})/);
    if (timeMatch) {
      document.getElementById('cfmVoiceTime').value = timeMatch[1].replace('：', ':');
      document.getElementById('cfmVoiceTitle').value = text.replace(timeMatch[0], '').trim();
    } else {
      document.getElementById('cfmVoiceTitle').value = text;
    }
  }

  document.getElementById('voiceTextInput').value = '';
  showVoiceConfirm();
}

// ── 中文时间解析 ──
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
  var periodMap = { '早上':0,'早晨':0,'凌晨':0,'上午':0,'中午':12,'下午':12,'傍晚':12,'晚上':12,'夜里':12,'夜间':12 };

  // 阿拉伯数字 + 时段前缀
  var m = text.match(/(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/);
  if (m) {
    var p = periodMap[m[1]], h = parseInt(m[2]), hasHalf = !!m[3], min = m[4] ? parseInt(m[4]) : (hasHalf ? 30 : 0);
    if (m[1] === '中午' && h === 12) h = 12;
    else if (m[1] === '中午' && h < 12) h += 12;
    else if (m[1] === '下午' && h === 12) h = 12;
    else h += p;
    if ((m[1] === '凌晨' || m[1] === '早上' || m[1] === '早晨') && h === 12) h = 0;
    var time = String(h % 24).padStart(2, '0') + ':' + String(min).padStart(2, '0');
    return { time: time, title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }

  // 中文数字 + 时段前缀
  m = text.match(/(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var p2 = periodMap[m[1]], h2 = cnDigits[m[2]], hasHalf2 = !!m[3], min2 = m[4] ? (cnDigits[m[4]] || parseInt(m[4])) : (hasHalf2 ? 30 : 0);
    if (isNaN(h2)) return null;
    if (m[1] === '中午' && h2 === 12) h2 = 12;
    else if (m[1] === '中午' && h2 < 12) h2 += 12;
    else if (m[1] === '下午' && h2 === 12) h2 = 12;
    else h2 += p2;
    if ((m[1] === '凌晨' || m[1] === '早上' || m[1] === '早晨') && h2 === 12) h2 = 0;
    var time2 = String(h2 % 24).padStart(2, '0') + ':' + String(min2).padStart(2, '0');
    return { time: time2, title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }

  // 裸阿拉伯数字
  m = text.match(/(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/);
  if (m) {
    var h3 = parseInt(m[1]), hasHalf3 = !!m[2], min3 = m[3] ? parseInt(m[3]) : (hasHalf3 ? 30 : 0);
    var ampm = inferAmPm(h3, text);
    if (ampm === 'pm' && h3 < 12) h3 += 12;
    if (ampm === 'am' && h3 === 12) h3 = 0;
    return { time: String(h3).padStart(2, '0') + ':' + String(min3).padStart(2, '0'), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }

  // 裸中文数字
  m = text.match(/([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/);
  if (m) {
    var h4 = cnDigits[m[1]], hasHalf4 = !!m[2], min4 = m[3] ? (cnDigits[m[3]] || parseInt(m[3])) : (hasHalf4 ? 30 : 0);
    if (isNaN(h4)) return null;
    var ampm2 = inferAmPm(h4, text);
    if (ampm2 === 'pm' && h4 < 12) h4 += 12;
    if (ampm2 === 'am' && h4 === 12) h4 = 0;
    return { time: String(h4).padStart(2, '0') + ':' + String(min4).padStart(2, '0'), title: text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim() };
  }

  return null;
}

// ── 确认卡片 ──
function populateVoiceConfirm(rawText) {
  var parsed = parseChineseTime(rawText);
  if (parsed) {
    document.getElementById('cfmVoiceTime').value = parsed.time;
    document.getElementById('cfmVoiceTitle').value = parsed.title;
    return;
  }
  var timeMatch = rawText.match(/(\d{1,2})[点:：](\d{0,2})/);
  var time = '09:00', title = rawText;
  if (timeMatch) {
    var h = parseInt(timeMatch[1]);
    if (/下午|晚上|中午/.test(rawText) && h < 12) h += 12;
    time = String(h).padStart(2, '0') + ':00';
    title = rawText.replace(timeMatch[0], '').replace(/[上午下午中午早晨晚上]/g, '').replace(/[在的于从]/g, '').trim();
  }
  document.getElementById('cfmVoiceTime').value = time;
  document.getElementById('cfmVoiceTitle').value = title || rawText;
}

function showVoiceConfirm() {
  document.getElementById('confirmVoiceOverlay').classList.add('active');
  var container = document.getElementById('cfmVoiceTags');
  var tags = (typeof getDynamicTags === 'function') ? getDynamicTags() : [
    { name: '工作', color: '#4A90D9' }, { name: '学习', color: '#50C878' }, { name: '生活', color: '#F5A623' }
  ];
  var title = (document.getElementById('cfmVoiceTitle') || {}).value || '';
  var suggestedTag = (typeof classifyVoiceText === 'function') ? classifyVoiceText(title) : null;
  var html = '';
  for (var i = 0; i < tags.length; i++) {
    var sel = (suggestedTag === tags[i].name || (!suggestedTag && i === 0)) ? ' selected' : '';
    html += '<button class="tag-chip' + sel + '" onclick="toggleVoiceTag(this)">' + tags[i].name + '</button>';
  }
  container.innerHTML = html;
}

function closeVoiceConfirm() {
  document.getElementById('confirmVoiceOverlay').classList.remove('active');
}

function toggleVoiceTag(el) { el.classList.toggle('selected'); }

function confirmVoiceTask() {
  var time = document.getElementById('cfmVoiceTime').value;
  var title = document.getElementById('cfmVoiceTitle').value.trim();
  if (!title) return;
  var chips = document.querySelectorAll('#cfmVoiceTags .tag-chip.selected'), selTags = [];
  for (var i = 0; i < chips.length; i++) selTags.push(chips[i].textContent);
  var tag = selTags[0] || '工作';
  if (!events[selectedDate]) events[selectedDate] = [];
  events[selectedDate].push({ time: time || '09:00', content: title, tag: tag, done: false });
  saveEvents();
  closeVoiceConfirm();
  document.getElementById('cfmVoiceTitle').value = '';
  var allChips = document.querySelectorAll('#cfmVoiceTags .tag-chip');
  for (var j = 0; j < allChips.length; j++) allChips[j].classList.remove('selected');
  if (allChips.length > 0) allChips[0].classList.add('selected');
  renderAll();
  if (typeof showToast === 'function') showToast('已添加：' + title);
}

// ── 标签分类 ──
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

// ── 事件绑定 ──
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
