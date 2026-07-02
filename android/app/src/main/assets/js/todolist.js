// 语程 — TodoList 模块
// 职责: 工作日/上学日待办列表，支持纯文字项和带时间项，循环提醒

// ====== 全局状态 ======
var todoList = [];
var todoFilter = 'all'; // all | workday | schoolday | completed
var todoEditId = null;

// ====== 数据层 (localStorage + API) ======
var TODO_STORAGE_KEY = 'pixel_todolist';

function loadTodoList() {
  try {
    var saved = localStorage.getItem(TODO_STORAGE_KEY);
    if (saved) { todoList = JSON.parse(saved); return; }
  } catch(e) {}
  todoList = [];
}

function saveTodoList() {
  localStorage.setItem(TODO_STORAGE_KEY, JSON.stringify(todoList));
  // 同步到服务器
  syncTodoToServer();
}

async function syncTodoToServer() {
  var uid = (typeof apiGetUser === 'function') ? apiGetUser() : null;
  if (!uid) return;
  try {
    await apiCall('POST', '/api/todolist?user_id=' + uid, { todos: todoList });
  } catch(e) {}
}

async function loadTodoFromServer() {
  var uid = (typeof apiGetUser === 'function') ? apiGetUser() : null;
  if (!uid) return;
  try {
    var r = await apiCall('GET', '/api/todolist?user_id=' + uid);
    if (r.ok && r.todos) {
      todoList = r.todos;
      localStorage.setItem(TODO_STORAGE_KEY, JSON.stringify(todoList));
    }
  } catch(e) {}
}

// ====== 生成唯一ID ======
function todoGenId() {
  return 'todo_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6);
}

// ====== 添加待办 ======
function todoAdd(text, time, type, repeatDays) {
  // type: 'workday' | 'schoolday' | 'once'
  // repeatDays: [] 或 ['mon','tue','wed','thu','fri','sat','sun']
  var item = {
    id: todoGenId(),
    text: text,
    time: time || '',       // '' = 纯文字，'08:30' = 带时间
    type: type || 'once',   // 循环类型
    repeatDays: repeatDays || [], // 循环日期
    completed: false,
    completedDates: [],     // 记录已完成的具体日期（用于循环项）
    createdAt: new Date().toISOString(),
    notify: true
  };
  todoList.unshift(item);
  saveTodoList();
  return item;
}

// ====== 切换完成状态 ======
function todoToggle(id, dateStr) {
  var item = null;
  for (var i = 0; i < todoList.length; i++) {
    if (todoList[i].id === id) { item = todoList[i]; break; }
  }
  if (!item) return;

  if (item.type === 'once') {
    item.completed = !item.completed;
  } else {
    // 循环项：按日期标记完成
    var ds = dateStr || dateKey(new Date());
    var idx = item.completedDates.indexOf(ds);
    if (idx === -1) {
      item.completedDates.push(ds);
    } else {
      item.completedDates.splice(idx, 1);
    }
  }
  saveTodoList();
}

// ====== 判断是否今日需显示 ======
function todoIsDueToday(item) {
  if (item.type === 'once') return !item.completed;
  var d = new Date();
  var dayMap = { 0:'sun',1:'mon',2:'tue',3:'wed',4:'thu',5:'fri',6:'sat' };
  var todayKey = dayMap[d.getDay()];
  if (item.repeatDays.indexOf(todayKey) === -1) return false;
  // 检查今天是否已标记完成
  var ds = dateKey(d);
  return item.completedDates.indexOf(ds) === -1;
}

// ====== 获取过滤后的列表 ======
function todoGetFiltered() {
  var today = new Date();
  var dayMap = { 0:'sun',1:'mon',2:'tue',3:'wed',4:'thu',5:'fri',6:'sat' };
  var todayStr = dateKey(today);
  var todayDay = dayMap[today.getDay()];

  if (todoFilter === 'workday') {
    return todoList.filter(function(item) {
      return item.type === 'workday' && item.repeatDays.indexOf(todayDay) !== -1;
    });
  }
  if (todoFilter === 'schoolday') {
    return todoList.filter(function(item) {
      return item.type === 'schoolday' && item.repeatDays.indexOf(todayDay) !== -1;
    });
  }
  if (todoFilter === 'completed') {
    return todoList.filter(function(item) {
      if (item.type === 'once') return item.completed;
      return item.completedDates.indexOf(todayStr) !== -1;
    });
  }
  // 'all': 显示今日待办 + 一次性未完成
  return todoList.filter(function(item) {
    if (item.type === 'once') return !item.completed;
    return item.repeatDays.indexOf(todayDay) !== -1 &&
           item.completedDates.indexOf(todayStr) === -1;
  });
}

// ====== 渲染 TodoList 面板 ======
function renderTodoPanel() {
  var container = document.getElementById('todoListPanel');
  if (!container) return;

  var filtered = todoGetFiltered();
  var html = '';

  // 头部过滤
  html += '<div class="todo-filter-bar">';
  var filters = [
    { key: 'all', label: '今日待办' },
    { key: 'workday', label: '工作日' },
    { key: 'schoolday', label: '上学日' },
    { key: 'completed', label: '已完成' }
  ];
  for (var f = 0; f < filters.length; f++) {
    html += '<button class="todo-filter-btn' + (todoFilter === filters[f].key ? ' sel' : '') +
            '" onclick="todoSetFilter(\'' + filters[f].key + '\')">' + filters[f].label + '</button>';
  }
  html += '</div>';

  // 列表
  if (filtered.length === 0) {
    html += '<div class="todo-empty">暂无待办事项</div>';
  } else {
    html += '<div class="todo-list-items">';
    for (var i = 0; i < filtered.length; i++) {
      var item = filtered[i];
      var isDone = item.type === 'once' ? item.completed :
                   (item.completedDates.indexOf(dateKey(new Date())) !== -1);
      var typeLabel = item.type === 'workday' ? '🏢 工作日' :
                     item.type === 'schoolday' ? '🎓 上学日' : '☐ 一次性';
      html += '<div class="todo-item' + (isDone ? ' todo-done' : '') + '" data-id="' + item.id + '">';
      html += '<div class="todo-chk" onclick="todoToggle(\'' + item.id + '\')">' + (isDone ? '✓' : '') + '</div>';
      html += '<div class="todo-body">';
      html += '<div class="todo-text">' + esc(item.text) + '</div>';
      if (item.time) html += '<div class="todo-time">' + esc(item.time) + '</div>';
      html += '<div class="todo-type-label">' + typeLabel + '</div>';
      html += '</div>';
      html += '<div class="todo-actions">';
      html += '<button class="todo-action-btn" onclick="todoEdit(\'' + item.id + '\')">✎</button>';
      html += '<button class="todo-action-btn todo-del-btn" onclick="todoDelete(\'' + item.id + '\')">✕</button>';
      html += '</div></div>';
    }
    html += '</div>';
  }

  // 添加按钮
  html += '<button class="todo-add-btn" onclick="todoShowAdd()">+ 添加待办</button>';

  container.innerHTML = html;
}

// ====== 过滤切换 ======
function todoSetFilter(f) {
  todoFilter = f;
  renderTodoPanel();
}

// ====== 显示添加弹窗 ======
function todoShowAdd() {
  document.getElementById('todoAddOverlay').classList.add('active');
  document.getElementById('todoAddText').value = '';
  document.getElementById('todoAddTime').value = '';
  document.getElementById('todoAddType').value = 'workday';
  todoUpdateRepeatCheckboxes();
}

function todoCloseAdd() {
  document.getElementById('todoAddOverlay').classList.remove('active');
}

function todoUpdateRepeatCheckboxes() {
  var type = document.getElementById('todoAddType').value;
  var container = document.getElementById('todoRepeatCheckboxes');
  if (!container) return;
  if (type === 'once') {
    container.style.display = 'none';
    return;
  }
  container.style.display = 'flex';
  var days = type === 'workday' ?
    [{key:'mon',label:'一'},{key:'tue',label:'二'},{key:'wed',label:'三'},{key:'thu',label:'四'},{key:'fri',label:'五'}] :
    [{key:'mon',label:'一'},{key:'tue',label:'二'},{key:'wed',label:'三'},{key:'thu',label:'四'},{key:'fri',label:'五'},{key:'sat',label:'六'},{key:'sun',label:'日'}];
  var html = '';
  for (var i = 0; i < days.length; i++) {
    html += '<label class="todo-day-label"><input type="checkbox" value="' + days[i].key + '" checked> ' + days[i].label + '</label>';
  }
  container.innerHTML = html;
}

// ====== 提交添加 ======
function todoSubmitAdd() {
  var text = document.getElementById('todoAddText').value.trim();
  if (!text) return;
  var time = document.getElementById('todoAddTime').value;
  var type = document.getElementById('todoAddType').value;
  var repeatDays = [];
  if (type !== 'once') {
    var checks = document.querySelectorAll('#todoRepeatCheckboxes input:checked');
    for (var i = 0; i < checks.length; i++) repeatDays.push(checks[i].value);
  }
  todoAdd(text, time, type, repeatDays);
  todoCloseAdd();
  renderTodoPanel();
  showToast('待办已添加');
}

// ====== 编辑 ======
function todoEdit(id) {
  var item = null;
  for (var i = 0; i < todoList.length; i++) {
    if (todoList[i].id === id) { item = todoList[i]; break; }
  }
  if (!item) return;
  todoEditId = id;
  document.getElementById('todoAddOverlay').classList.add('active');
  document.getElementById('todoAddText').value = item.text;
  document.getElementById('todoAddTime').value = item.time || '';
  document.getElementById('todoAddType').value = item.type || 'once';
  todoUpdateRepeatCheckboxes();
  // 勾选已有循环日
  if (item.repeatDays) {
    var checks = document.querySelectorAll('#todoRepeatCheckboxes input');
    for (var j = 0; j < checks.length; j++) {
      checks[j].checked = item.repeatDays.indexOf(checks[j].value) !== -1;
    }
  }
  // 修改按钮文字
  var submitBtn = document.getElementById('todoAddSubmit');
  if (submitBtn) submitBtn.textContent = '保存修改';
}

function todoSubmitEdit() {
  if (!todoEditId) return;
  var item = null;
  for (var i = 0; i < todoList.length; i++) {
    if (todoList[i].id === todoEditId) { item = todoList[i]; break; }
  }
  if (!item) return;
  item.text = document.getElementById('todoAddText').value.trim();
  item.time = document.getElementById('todoAddTime').value;
  item.type = document.getElementById('todoAddType').value;
  item.repeatDays = [];
  if (item.type !== 'once') {
    var checks = document.querySelectorAll('#todoRepeatCheckboxes input:checked');
    for (var i = 0; i < checks.length; i++) item.repeatDays.push(checks[i].value);
  }
  todoEditId = null;
  saveTodoList();
  todoCloseAdd();
  renderTodoPanel();
  var btn = document.getElementById('todoAddSubmit');
  if (btn) btn.textContent = '添加';
  showToast('待办已更新');
}

// ====== 删除 ======
function todoDelete(id) {
  if (!confirm('确认删除此待办？')) return;
  todoList = todoList.filter(function(item) { return item.id !== id; });
  saveTodoList();
  renderTodoPanel();
  showToast('待办已删除');
}

// ====== 初始化 ======
function initTodoList() {
  loadTodoList();
  // 尝试从服务器加载
  if (typeof apiGetUser === 'function' && apiGetUser()) {
    loadTodoFromServer().then(function() {
      renderTodoPanel();
    });
  }
}

// 监听类型切换
document.addEventListener('change', function(e) {
  if (e.target && e.target.id === 'todoAddType') {
    todoUpdateRepeatCheckboxes();
  }
});

// 统一提交按钮
function todoSubmit() {
  if (todoEditId) {
    todoSubmitEdit();
  } else {
    todoSubmitAdd();
  }
}
