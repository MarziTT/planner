// 语程 — 语音交互模块
// 职责: 语音区交互(toggleVoiceZone)、文本提交、确认卡片、语音标签分类

// ==================== 语音区 v3.11 (Android 原生语音识别) ====================

var voiceResultText = '';
var voicePartialText = '';

function toggleVoiceZone() {
  console.log('toggleVoiceZone called, isRecording:', voiceIsRecording);
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');
  var input = document.getElementById('voiceTextInput');

  // 调试：写入反馈文字
  if (input) input.value = '点击已触发...';

  if (voiceIsRecording) {
    // 停止录音
    clearTimeout(voiceRecTimer);
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '点击开始语音记录';

    if (typeof AndroidBridge !== 'undefined' && AndroidBridge.stopVoiceRecognition) {
      AndroidBridge.stopVoiceRecognition();
    }

    if (voiceResultText) {
      submitVoiceText();
    }
  } else {
    // 检查 Android 桥接是否可用
    if (typeof AndroidBridge === 'undefined') {
      hint.textContent = 'Android 桥接未就绪';
      if (input) input.value = '桥接未就绪，请重启 App';
      return;
    }
    if (!AndroidBridge.startVoiceRecognition) {
      hint.textContent = '语音识别接口不可用';
      if (input) input.value = '接口不可用';
      return;
    }

    voiceResultText = '';
    voicePartialText = '';
    zone.classList.add('recording');
    voiceIsRecording = true;
    hint.textContent = '正在聆听...';
    if (input) input.value = '正在聆听...';
    AndroidBridge.startVoiceRecognition();

    voiceRecTimer = setTimeout(function() {
      toggleVoiceZone();
    }, 8000);
  }
}

// ==================== Android 语音回调 ====================

function onVoiceStart() {
  console.log('Voice: start');
}

function onVoiceReady() {
  console.log('Voice: ready');
  document.getElementById('voiceHint').textContent = '请说话...';
}

function onVoiceSpeaking() {
  console.log('Voice: speaking');
  document.getElementById('voiceHint').textContent = '识别中...';
}

function onVoiceEnd() {
  console.log('Voice: end');
  document.getElementById('voiceHint').textContent = '处理中...';
}

function onVoiceResult(text) {
  console.log('Voice: result =', text);
  voiceResultText = text;
  document.getElementById('voiceTextInput').value = text;
}

function onVoicePartial(text) {
  console.log('Voice: partial =', text);
  voicePartialText = text;
  document.getElementById('voiceHint').textContent = text;
}

function onVoiceError(msg) {
  console.log('Voice: error =', msg);
  voiceIsRecording = false;
  clearTimeout(voiceRecTimer);
  document.getElementById('voiceZone').classList.remove('recording');
  document.getElementById('voiceHint').textContent = msg || '识别失败，请重试';
  if (typeof showToast === 'function') {
    showToast('语音识别失败: ' + (msg || '未知错误'));
  }
}

function onVoicePermissionGranted() {
  // 权限授予后自动重试
  if (typeof AndroidBridge !== 'undefined' && AndroidBridge.startVoiceRecognition) {
    AndroidBridge.startVoiceRecognition();
  }
}

function submitVoiceText() {
  var text = voiceResultText || '';
  if (!text) {
    var input = document.getElementById('voiceTextInput');
    text = input ? input.value.trim() : '';
  }
  if (!text) return;

  // Parse time from text — support Chinese time expressions
  var parsed = parseChineseTime(text);
  if (parsed) {
    document.getElementById('cfmVoiceTime').value = parsed.time;
    document.getElementById('cfmVoiceTitle').value = parsed.title;
  } else {
    // Also try colon-based time match
    var timeMatch = text.match(/(\d{1,2}[:：]\d{2})/);
    if (timeMatch) {
      document.getElementById('cfmVoiceTime').value = timeMatch[1].replace('：', ':');
      document.getElementById('cfmVoiceTitle').value = text.replace(timeMatch[0], '').trim();
    } else {
      document.getElementById('cfmVoiceTitle').value = text;
    }
  }

  input.value = '';
  showVoiceConfirm();
}

// ==================== 中文时间解析 ====================
// 支持: "上午10点"、"下午七点"、"晚上8点"、"早上六点"、"中午12点"、"傍晚5点"、"凌晨3点"
// 也支持: "明天上午10点"、"后天下午3点" 等含日期前缀的
// 也支持: 裸时间表达式 "六点半下班"、"3点开会" 等（通过语境推断 AM/PM）

// 推断无时段前缀时间的 AM/PM
function inferAmPm(h, text) {
  // 语境线索优先
  if (/下班|晚饭|晚餐|晚上/.test(text)) return 'pm';
  if (/上班|早|晨/.test(text)) return 'am';
  // 默认推断：8-11 点 → AM，1-6点或12点 → PM，7点 → AM
  if (h >= 8 && h <= 11) return 'am';
  if ((h >= 1 && h <= 6) || h === 12) return 'pm';
  return 'am';
}

function parseChineseTime(text) {
  // Pattern: optional date prefix + period word + digits + optional (点/时) + optional minutes
  var periodMap = {
    '早上': 0, '早晨': 0, '凌晨': 0,
    '上午': 0,
    '中午': 12,
    '下午': 12,
    '傍晚': 12, '晚上': 12, '夜里': 12, '夜间': 12
  };

  // Match: (optional prefix) + period + number + optional 点/时 + optional 分
  // Support both Arabic and Chinese digits
  var cnDigits = { '零':0,'一':1,'二':2,'两':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9,
                   '十':10,'十一':11,'十二':12,'十三':13,'十四':14,'十五':15 };

  // Try Arabic digit pattern: (prefix) + period + digits + (点/时) + optional 半 + optional digits分
  var re1 = /(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/;
  var m = text.match(re1);
  if (m) {
    var period = m[1];
    var h = parseInt(m[2]);
    var hasHalf = !!m[3];
    var min = m[4] ? parseInt(m[4]) : (hasHalf ? 30 : 0);
    var offset = periodMap[period] || 0;
    if (period === '中午' && h === 12) h = 12;
    else if (period === '中午' && h < 12) h += 12;
    else if (period === '下午' && h === 12) h = 12;
    else h += offset;
    // Special: 凌晨/早上/早晨 的 12 点 = 0 点
    if ((period === '凌晨' || period === '早上' || period === '早晨') && h === 12) h = 0;
    if (h > 23) h = h - 24;
    var time = String(h).padStart(2, '0') + ':' + String(min).padStart(2, '0');

    // Extract title: remove the matched time portion
    var title = text.replace(m[0], '').replace(/[在的于从去要]/g, '').trim();
    return { time: time, title: title };
  }

  // Try Chinese digit pattern: 下午七点, 晚上八点半
  var re2 = /(早上|早晨|凌晨|上午|中午|下午|傍晚|晚上|夜里|夜间)\s*([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/;
  var m2 = text.match(re2);
  if (m2) {
    var period2 = m2[1];
    var hcn = m2[2];
    var hasHalf2 = !!m2[3];
    var mincn = m2[4] || '';
    var h2 = cnDigits[hcn] !== undefined ? cnDigits[hcn] : parseInt(hcn);
    var min2 = hasHalf2 ? 30 : (mincn ? (cnDigits[mincn] !== undefined ? cnDigits[mincn] : parseInt(mincn)) : 0);
    if (isNaN(h2)) return null;
    var offset2 = periodMap[period2] || 0;
    if (period2 === '中午' && h2 === 12) h2 = 12;
    else if (period2 === '中午' && h2 < 12) h2 += 12;
    else if (period2 === '下午' && h2 === 12) h2 = 12;
    else h2 += offset2;
    if ((period2 === '凌晨' || period2 === '早上' || period2 === '早晨') && h2 === 12) h2 = 0;
    if (h2 > 23) h2 = h2 - 24;
    var time2 = String(h2).padStart(2, '0') + ':' + String(min2).padStart(2, '0');
    var title2 = text.replace(m2[0], '').replace(/[在的于从去要]/g, '').trim();
    return { time: time2, title: title2 };
  }

  // Try bare Arabic digit pattern (no period prefix): "六点半下班", "3点开会"
  var re3 = /(\d{1,2})\s*(?:点|时)\s*(半)?\s*(?:(\d{1,2})\s*分)?/;
  var m3 = text.match(re3);
  if (m3) {
    var h3 = parseInt(m3[1]);
    var hasHalf3 = !!m3[2];
    var min3 = m3[3] ? parseInt(m3[3]) : (hasHalf3 ? 30 : 0);
    var ampm3 = inferAmPm(h3, text);
    if (ampm3 === 'pm' && h3 < 12) h3 += 12;
    if (ampm3 === 'am' && h3 === 12) h3 = 0;
    var time3 = String(h3).padStart(2, '0') + ':' + String(min3).padStart(2, '0');
    var title3 = text.replace(m3[0], '').replace(/[在的于从去要]/g, '').trim();
    return { time: time3, title: title3 };
  }

  // Try bare Chinese digit pattern: "六点半下班"
  var re4 = /([零一二两三四五六七八九十]+)\s*(?:点|时)\s*(半)?\s*(?:([零一二两三四五六七八九十]+)\s*分)?/;
  var m4 = text.match(re4);
  if (m4) {
    var hcn4 = m4[1];
    var hasHalf4 = !!m4[2];
    var mincn4 = m4[3] || '';
    var h4 = cnDigits[hcn4] !== undefined ? cnDigits[hcn4] : parseInt(hcn4);
    var min4 = hasHalf4 ? 30 : (mincn4 ? (cnDigits[mincn4] !== undefined ? cnDigits[mincn4] : parseInt(mincn4)) : 0);
    if (isNaN(h4)) return null;
    var ampm4 = inferAmPm(h4, text);
    if (ampm4 === 'pm' && h4 < 12) h4 += 12;
    if (ampm4 === 'am' && h4 === 12) h4 = 0;
    var time4 = String(h4).padStart(2, '0') + ':' + String(min4).padStart(2, '0');
    var title4 = text.replace(m4[0], '').replace(/[在的于从去要]/g, '').trim();
    return { time: time4, title: title4 };
  }

  return null;
}

function populateVoiceConfirm(rawText) {
  // Try parse with full Chinese time logic first
  var parsed = parseChineseTime(rawText);
  if (parsed) {
    document.getElementById('cfmVoiceTime').value = parsed.time;
    document.getElementById('cfmVoiceTitle').value = parsed.title;
    return;
  }

  // Fallback: simple extraction for legacy patterns
  var time = '09:00';
  var title = rawText;

  var timePatterns = [
    /(\d{1,2})[点:：](\d{0,2})/,
    /(\d{1,2})[点时]/
  ];

  for (var i = 0; i < timePatterns.length; i++) {
    var m = rawText.match(timePatterns[i]);
    if (m) {
      var h = parseInt(m[1]);
      if (rawText.indexOf('下午') !== -1 && h < 12) h += 12;
      if (rawText.indexOf('晚上') !== -1 && h < 12) h += 12;
      if (rawText.indexOf('中午') !== -1 && h < 12) h += 12;
      time = String(h).padStart(2, '0') + ':00';
      title = rawText.replace(m[0], '').replace(/[上午下午中午早晨晚上]/g, '').replace(/[在的于从]/g, '').trim();
      break;
    }
  }

  document.getElementById('cfmVoiceTime').value = time;
  document.getElementById('cfmVoiceTitle').value = title || rawText;
}

function showVoiceConfirm() {
  var overlay = document.getElementById('confirmVoiceOverlay');
  overlay.classList.add('active');

  // Populate tag chips from dynamic tags
  var container = document.getElementById('cfmVoiceTags');
  var tags = (typeof getDynamicTags === 'function') ? getDynamicTags() : [
    { name: '工作', color: '#4A90D9' },
    { name: '学习', color: '#50C878' },
    { name: '生活', color: '#F5A623' }
  ];

  // Detect suggested tag from title
  var title = (document.getElementById('cfmVoiceTitle') || {}).value || '';
  var suggestedTag = (typeof classifyVoiceText === 'function') ? classifyVoiceText(title) : null;

  var html = '';
  for (var i = 0; i < tags.length; i++) {
    var t = tags[i];
    var sel = (suggestedTag === t.name || (!suggestedTag && i === 0)) ? ' selected' : '';
    html += '<button class="tag-chip' + sel + '" onclick="toggleVoiceTag(this)">' + t.name + '</button>';
  }
  container.innerHTML = html;
}

function closeVoiceConfirm() {
  document.getElementById('confirmVoiceOverlay').classList.remove('active');
}

function toggleVoiceTag(el) {
  el.classList.toggle('selected');
}

function confirmVoiceTask() {
  var time = document.getElementById('cfmVoiceTime').value;
  var title = document.getElementById('cfmVoiceTitle').value.trim();
  if (!title) return;

  // Get selected tags
  var selectedChips = document.querySelectorAll('#cfmVoiceTags .tag-chip.selected');
  var selectedTags = [];
  for (var i = 0; i < selectedChips.length; i++) {
    selectedTags.push(selectedChips[i].textContent);
  }

  // Determine tag for event (use first selected or default)
  var tag = selectedTags[0] || '工作';

  // Add to events using existing data structure
  if (!events[selectedDate]) events[selectedDate] = [];
  events[selectedDate].push({
    time: time || '09:00',
    content: title,
    tag: tag,
    done: false
  });

  // Persist
  saveEvents();

  // Close overlay and refresh
  closeVoiceConfirm();

  // Reset form
  document.getElementById('cfmVoiceTitle').value = '';
  var allChips = document.querySelectorAll('#cfmVoiceTags .tag-chip');
  for (var j = 0; j < allChips.length; j++) allChips[j].classList.remove('selected');
  if (allChips.length > 0) allChips[0].classList.add('selected');

  // Refresh UI
  renderAll();

  // Show toast
  if (typeof showToast === 'function') {
    showToast('已添加：' + title);
  }
}


// ==================== 语音标签分类 ====================
function classifyVoiceText(text) {
  if (!text) return null;
  var lower = text.toLowerCase();
  var bestTag = null;
  var bestScore = 0;

  for (var i = 0; i < VOICE_TAG_RULES.length; i++) {
    var rule = VOICE_TAG_RULES[i];
    var score = 0;
    for (var j = 0; j < rule.keys.length; j++) {
      if (lower.indexOf(rule.keys[j]) !== -1) {
        score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestTag = rule.tag;
    }
  }

  // Check if the tag exists in dynamic tags, if not suggest as new
  if (bestTag && bestScore > 0) {
    var tags = getDynamicTags();
    var exists = false;
    for (var k = 0; k < tags.length; k++) {
      if (tags[k].name === bestTag) { exists = true; break; }
    }
    if (!exists) {
      // Auto-create the tag
      var colors = ['#4A90D9','#50C878','#F5A623','#E85D75','#9B59B6','#1ABC9C','#E67E22','#3498DB'];
      var colorIdx = tags.length % colors.length;
      tags.push({ name: bestTag, color: colors[colorIdx], emoji: '🏷️' });
      saveDynamicTags(tags);
      syncAllTags();
    }
    return bestTag;
  }
  return null;
}

// ==================== 事件绑定（addEventListener 替代 onclick） ====================
(function initVoiceEvents() {
  // 防重复绑定
  if (window._voiceEventsBound) return;
  window._voiceEventsBound = true;

  // 语音圆环点击（只用 click，避免 touchend+click 双重触发）
  var ring = document.getElementById('voiceRing');
  if (ring) {
    ring.addEventListener('click', function(e) {
      e.preventDefault();
      toggleVoiceZone();
    });
  }

  // 提交按钮
  var btn = document.getElementById('voiceSubmitBtn');
  if (btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      submitVoiceText();
    });
  }

  // 输入框回车提交
  var input = document.getElementById('voiceTextInput');
  if (input) {
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        submitVoiceText();
      }
    });
  }
})();

