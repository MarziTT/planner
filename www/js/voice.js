// 语程 — 语音交互模块
// 职责: 语音区交互(toggleVoiceZone)、文本提交、确认卡片、语音标签分类

// ==================== 语音区 v3.3 ====================
function toggleVoiceZone() {
  var zone = document.getElementById('voiceZone');
  var hint = document.getElementById('voiceHint');

  if (voiceIsRecording) {
    // Stop recording
    clearTimeout(voiceRecTimer);
    zone.classList.remove('recording');
    voiceIsRecording = false;
    hint.textContent = '正在识别...';

    // Simulate AI parsing -> populate confirm overlay
    setTimeout(function() {
      hint.textContent = '点击开始语音记录';
      populateVoiceConfirm('明天上午10点产品评审会议');
      showVoiceConfirm();
    }, 2000);
  } else {
    // Start recording (simulated)
    zone.classList.add('recording');
    voiceIsRecording = true;
    hint.textContent = '正在聆听...';

    // Auto-stop after 8s
    voiceRecTimer = setTimeout(function() {
      toggleVoiceZone();
    }, 8000);
  }
}

function submitVoiceText() {
  var input = document.getElementById('voiceTextInput');
  var text = input.value.trim();
  if (!text) return;

  // Parse time from text
  var timeMatch = text.match(/(\d{1,2}[:：]\d{2})/);
  if (timeMatch) {
    document.getElementById('cfmVoiceTime').value = timeMatch[1].replace('：', ':');
    document.getElementById('cfmVoiceTitle').value = text.replace(timeMatch[0], '').trim();
  } else {
    document.getElementById('cfmVoiceTitle').value = text;
  }

  input.value = '';
  showVoiceConfirm();
}

function populateVoiceConfirm(rawText) {
  // AI simulation: parse "明天上午10点产品评审会议" -> time=10:00, title=产品评审会议
  // Simple extraction
  var time = '09:00';
  var title = rawText;

  // Try extract time patterns
  var timePatterns = [
    /(\d{1,2})[点:：](\d{0,2})/,
    /(\d{1,2})[点时]/,
    /上午(\d{1,2})/,
    /下午(\d{1,2})/
  ];

  for (var i = 0; i < timePatterns.length; i++) {
    var m = rawText.match(timePatterns[i]);
    if (m) {
      var h = parseInt(m[1]);
      if (rawText.indexOf('下午') !== -1 && h < 12) h += 12;
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

