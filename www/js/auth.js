// 语程 — 登录注册模块
// 职责: handleAuth、toggleAuthMode、doLogout、showMainApp、问卷系统、标签初始化

// ==================== 认证模块 ====================
var currentUser = '';

function getUsers() {
  try { console.warn("getUsers() called in SQLite mode"); return {}; }
  catch(e) { return {}; }
}
function saveUsers(users) { /* SQLite mode */ }
function getCurrentUser() {
  return localStorage.getItem('pixel_username') || '';
}
function isLoggedIn() {
  return apiGetUser() !== null && getCurrentUser() !== '';
}

// ====== 1. AUTH MODULE ======
var authIsRegister = false;

function toggleAuthMode() {
  authIsRegister = !authIsRegister;
  document.getElementById('loginSub').textContent = authIsRegister ? '创建新账号' : '登录以继续';
  document.getElementById('loginSubmitBtn').textContent = authIsRegister ? '注 册' : '登 录';
  document.getElementById('toggleModeBtn').textContent = authIsRegister ? '已有账号？去登录' : '没有账号？去注册';
  document.getElementById('confirmField').style.display = authIsRegister ? '' : 'none';
  document.getElementById('loginErr').classList.remove('show');
  document.getElementById('regConfirmPw').value = '';
}

async function handleAuth() {
  var userEl = document.getElementById('loginUser');
  var pwEl = document.getElementById('loginPw');
  var errEl = document.getElementById('loginErr');
  var user = userEl.value.trim();
  var pw = pwEl.value;

  if (!user || !pw) {
    errEl.textContent = '请填写用户名和密码'; errEl.classList.add('show'); return;
  }
  if (authIsRegister) {
    var confirmPw = document.getElementById('regConfirmPw').value;
    if (pw !== confirmPw) {
      errEl.textContent = '两次密码不一致'; errEl.classList.add('show'); return;
    }
    if (pw.length < 4) {
      errEl.textContent = '密码至少4位'; errEl.classList.add('show'); return;
    }

    setAuthLoading(true);

    // [v3.2 SQLite] Register via API
    var regR = await apiCall('POST', '/api/register', { username: user, password: pw });
    if (!regR.ok) {
      errEl.textContent = (regR.error) || '注册失败'; errEl.classList.add('show');
      setAuthLoading(false);
      return;
    }
    apiSetUser(regR.user_id);
    localStorage.setItem('pixel_username', user);

    // Check if first time — always show questionnaire for new users
    var profile = await apiGetProfile();
    setAuthLoading(false);
    if (!profile || !profile.identity) {
      showQuestionnaire();
    } else {
      showMainApp();
    }
  } else {
    setAuthLoading(true);

    // [v3.2 SQLite] Login via API
    var loginR = await apiCall('POST', '/api/login', { username: user, password: pw });
    if (!loginR.ok) {
      errEl.textContent = (loginR.error) || '登录失败'; errEl.classList.add('show');
      setAuthLoading(false);
      return;
    }
    apiSetUser(loginR.user_id);
    localStorage.setItem('pixel_username', user);

    // Check profile
    var profile = await apiGetProfile();
    setAuthLoading(false);
    if (!profile || !profile.identity) {
      showQuestionnaire();
    } else {
      showMainApp();
    }
  }
}

function setAuthLoading(loading) {
  var submitBtn = document.getElementById('loginSubmitBtn');
  var userEl = document.getElementById('loginUser');
  var pwEl = document.getElementById('loginPw');
  var confirmEl = document.getElementById('regConfirmPw');

  if (loading) {
    submitBtn.disabled = true;
    submitBtn.textContent = authIsRegister ? '注册中...' : '登录中...';
    userEl.disabled = true;
    pwEl.disabled = true;
    if (confirmEl) confirmEl.disabled = true;
  } else {
    submitBtn.disabled = false;
    submitBtn.textContent = authIsRegister ? '注 册' : '登 录';
    userEl.disabled = false;
    pwEl.disabled = false;
    if (confirmEl) confirmEl.disabled = false;
  }
}

function doLogout() {
  apiClearUser();
  localStorage.removeItem('pixel_username');
  document.getElementById('loginScreen').style.display = 'flex';
  document.getElementById('mainApp').style.display = 'none';
  document.getElementById('loginUser').value = '';
  document.getElementById('loginPw').value = '';
  document.getElementById('regConfirmPw').value = '';
  document.getElementById('loginErr').classList.remove('show');
  closeSettings();
}

function showMainApp() {
  document.getElementById('loginScreen').style.display = 'none';
  document.getElementById('mainApp').style.display = '';
  document.getElementById('questionnaireOverlay').style.display = 'none';
  // Reset auth form
  document.getElementById('loginUser').value = '';
  document.getElementById('loginPw').value = '';
  document.getElementById('regConfirmPw').value = '';
  document.getElementById('loginErr').classList.remove('show');
  // [v3.2 SQLite] Load data from server
  if (typeof initDataFromServer === 'function') { setTimeout(function() { initDataFromServer(); }, 200); }
  // Refresh UI
  if (typeof renderAll === 'function') renderAll();
}

// ====== 2. QUESTIONNAIRE ======
var quizSteps = [
  {
    q: '你的身份是？',
    opts: ['学生', '上班族', '自由职业', '老师', '其他'],
    key: 'identity'
  },
  {
    q: '你的主要目标？',
    opts: ['提高效率', '健康管理', '学习规划', '工作安排', '综合'],
    key: 'goal'
  },
  {
    q: '你常用的标签偏好？（可多选）',
    opts: ['工作', '学习', '运动', '社交', '娱乐', '健康', '出行'],
    key: 'prefTags',
    multi: true
  }
];
var quizIdx = 0;
var quizAnswers = {};
var quizMultiSel = [];

function showQuestionnaire() {
  quizIdx = 0; quizAnswers = {}; quizMultiSel = [];
  document.getElementById('loginScreen').style.display = 'none';
  document.getElementById('mainApp').style.display = 'none';
  document.getElementById('questionnaireOverlay').style.display = 'flex';
  renderQuizStep();
}

function renderQuizStep() {
  var step = quizSteps[quizIdx];
  document.getElementById('quizQ').textContent = step.q;
  document.getElementById('quizSub').textContent = '问题 ' + (quizIdx + 1) + ' / ' + quizSteps.length;
  document.getElementById('quizSkip').style.display = '';

  // Dots
  var dotsHtml = '';
  for (var i = 0; i < quizSteps.length; i++) {
    dotsHtml += '<div class="dot' + (i === quizIdx ? ' active' : '') + '"></div>';
  }
  document.getElementById('quizDots').innerHTML = dotsHtml;

  // Options
  quizMultiSel = [];
  var optsHtml = '';
  for (var j = 0; j < step.opts.length; j++) {
    var o = step.opts[j];
    var selClass = (step.multi && quizAnswers[step.key] && quizAnswers[step.key].indexOf(o) !== -1) ? ' sel' : '';
    var clickFn = step.multi
      ? ('onclick="quizToggleMulti(\'' + o.replace(/'/g,"\\'") + '\', this)"')
      : ('onclick="quizPick(\'' + o.replace(/'/g,"\\'") + '\')"');
    optsHtml += '<div class="quiz-opt' + selClass + '" ' + clickFn + '>' + o + '</div>';
  }
  document.getElementById('quizOpts').innerHTML = optsHtml;
}

function quizPick(val) {
  var step = quizSteps[quizIdx];
  if (step.multi) return; // handled separately
  quizAnswers[step.key] = val;
  nextQuiz();
}

function quizToggleMulti(val, el) {
  var step = quizSteps[quizIdx];
  if (!quizAnswers[step.key]) quizAnswers[step.key] = [];
  var arr = quizAnswers[step.key];
  var idx = arr.indexOf(val);
  if (idx === -1) { arr.push(val); el.classList.add('sel'); }
  else { arr.splice(idx, 1); el.classList.remove('sel'); }
}

function nextQuiz() {
  quizIdx++;
  if (quizIdx >= quizSteps.length) {
    quizFinish();
  } else {
    renderQuizStep();
  }
}

function quizSkip() {
  nextQuiz();
}

function quizFinish() {
  var profile = {
    identity: quizAnswers.identity || '',
    goal: quizAnswers.goal || '',
    prefTags: quizAnswers.prefTags || [],
    completedAt: Date.now()
  };
  // [v3.2 SQLite] Save profile via API
  apiSaveProfile(profile);

  // Pre-populate tags based on preferences
  var prefTags = profile.prefTags;
  if (prefTags && prefTags.length > 0) {
    ensureDefaultTagsWith(prefTags);
  }

  // Theme recommendation based on identity
  if (profile.identity === '学生' && currentTheme !== 'clean') {
    setTh('clean');
  } else if (profile.identity === '上班族' && currentTheme !== 'dark') {
    setTh('dark');
  }

  showMainApp();
  showToast('欢迎使用语程！');
}

function ensureDefaultTagsWith(extraTags) {
  var tags = getDynamicTags();
  var existingNames = tags.map(function(t){ return t.name; });
  var defaults = [
    { name: '工作', color: '#4A90D9', emoji: '💼' },
    { name: '学习', color: '#50C878', emoji: '📚' },
    { name: '生活', color: '#F5A623', emoji: '🏠' }
  ];
  for (var i = 0; i < defaults.length; i++) {
    if (existingNames.indexOf(defaults[i].name) === -1) {
      tags.push(defaults[i]);
      existingNames.push(defaults[i].name);
    }
  }
  for (var j = 0; j < extraTags.length; j++) {
    var en = extraTags[j];
    if (existingNames.indexOf(en) === -1) {
      var colors = ['#E85D75','#9B59B6','#1ABC9C','#E67E22','#3498DB'];
      var emojis = ['🏃','🎉','🎮','🏥','✈️'];
      tags.push({ name: en, color: colors[j % colors.length], emoji: emojis[j] || '📌' });
    }
  }
  saveDynamicTags(tags);
}
