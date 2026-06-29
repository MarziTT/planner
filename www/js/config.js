// 语程 — 全局配置与常量
// 包含: API客户端、存储密钥、农历数据、训练模板、标签规则、日期工具

// ====== SQLite API Client Layer (v3.2) ======
var API_BASE = (window.location.hostname === 'localhost') ? 'http://localhost:5000' : 'https://planner-production-d1ee.up.railway.app';
var _pixel_user_id = null;

function apiSetUser(uid) { _pixel_user_id = uid; sessionStorage.setItem('pixel_uid', uid); }
function apiGetUser() {
  if (!_pixel_user_id) { _pixel_user_id = parseInt(sessionStorage.getItem('pixel_uid')) || null; }
  return _pixel_user_id;
}
function apiClearUser() { _pixel_user_id = null; sessionStorage.removeItem('pixel_uid'); }

async function apiCall(method, path, body) {
  try {
    var opts = { method: method, headers: { 'Content-Type': 'application/json' } };
    if (body !== undefined) opts.body = JSON.stringify(body);
    var resp = await fetch(API_BASE + path, opts);
    var data = await resp.json();
    return data;
  } catch(err) {
    console.error('[API Error]', method, path, err);
    return { ok: false, error: '网络错误：无法连接到服务器' };
  }
}

async function apiGetEvents(date) {
  var uid = apiGetUser(); if (!uid) return [];
  var path = '/api/events?user_id=' + uid + (date ? '&date=' + date : '');
  var r = await apiCall('GET', path);
  return (r.ok && r.events) ? r.events : [];
}

async function apiSaveEvent(ev) {
  var uid = apiGetUser(); if (!uid) return null;
  if (ev.id) {
    var r = await apiCall('PUT', '/api/events/' + ev.id + '?user_id=' + uid, ev);
    return (r.ok && r.event) ? r.event : null;
  } else {
    ev.user_id = uid;
    var r = await apiCall('POST', '/api/events?user_id=' + uid, ev);
    return (r.ok && r.event) ? r.event : null;
  }
}

async function apiDeleteEvent(eventId) {
  var uid = apiGetUser(); if (!uid) return false;
  var r = await apiCall('DELETE', '/api/events/' + eventId + '?user_id=' + uid);
  return r.ok;
}

async function apiGetTags() {
  var uid = apiGetUser(); if (!uid) return [];
  var r = await apiCall('GET', '/api/tags?user_id=' + uid);
  return (r.ok && r.tags) ? r.tags : [];
}

async function apiSaveTag(tag) {
  var uid = apiGetUser(); if (!uid) return null;
  if (tag.id) {
    var r = await apiCall('PUT', '/api/tags/' + tag.id + '?user_id=' + uid, tag);
    return (r.ok && r.tag) ? r.tag : null;
  } else {
    var r = await apiCall('POST', '/api/tags?user_id=' + uid, tag);
    return (r.ok && r.tag) ? r.tag : null;
  }
}

async function apiDeleteTag(tagId) {
  var uid = apiGetUser(); if (!uid) return false;
  var r = await apiCall('DELETE', '/api/tags/' + tagId + '?user_id=' + uid);
  return r.ok;
}

async function apiGetProfile() {
  var uid = apiGetUser(); if (!uid) return null;
  var r = await apiCall('GET', '/api/profile?user_id=' + uid);
  return (r.ok && r.profile) ? r.profile : null;
}

async function apiSaveProfile(profile) {
  var uid = apiGetUser(); if (!uid) return false;
  var r = await apiCall('PUT', '/api/profile?user_id=' + uid, profile);
  return r.ok;
}

async function apiGetSettings() {
  var uid = apiGetUser(); if (!uid) return { theme: 'solar' };
  var r = await apiCall('GET', '/api/settings?user_id=' + uid);
  return (r.ok && r.settings) ? r.settings : { theme: 'solar' };
}

async function apiSaveSettings(settings) {
  var uid = apiGetUser(); if (!uid) return false;
  var r = await apiCall('PUT', '/api/settings?user_id=' + uid, settings);
  return r.ok;
}


// ==================== 数据存储密钥 ====================
var STORAGE_KEY = 'pixel_planner_events';
var DATA_KEY = 'pixel_events_data';
var THEME_KEY = 'pixel_theme';
var AUTH_KEY = 'pixel_auth';
var AUTH_USER_KEY = 'pixel_current_user';
var USERS_KEY = 'pixel_users';
var TAGS_STORAGE_KEY = 'pixel_dynamic_tags';


// ==================== 农历计算数据 ====================
var lunarInfo = [0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,0x06ca0,0x0b550,0x15355,0x04da0,0x0a5b0,0x14573,0x052b0,0x0a9a8,0x0e950,0x06aa0,0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b6a0,0x195a6,0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x05ac0,0x0ab60,0x096d5,0x092e0,0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,0x05aa0,0x076a3,0x096d0,0x04afb,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,0x14b63,0x09370,0x049f8,0x04970,0x064b0,0x168a6,0x0ea50,0x06aa0,0x1a6c4,0x0aae0,0x092e0,0x0d2e3,0x0c960,0x0d557,0x0d4a0,0x0da50,0x05d55,0x056a0,0x0a6d0,0x055d4,0x052d0,0x0a9b8,0x0a950,0x0b4a0,0x0b6a6,0x0ad50,0x055a0,0x0aba4,0x0a5b0,0x052b0,0x0b273,0x06930,0x07337,0x06aa0,0x0ad50,0x14b55,0x04b60,0x0a570,0x054e4,0x0d160,0x0e968,0x0d520,0x0daa0,0x16aa6,0x056d0,0x04ae0,0x0a9d4,0x0a4d0,0x0d150,0x0f252,0x0d520];
var GAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
var ZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
var ZODIAC = ['鼠','牛','虎','兔','龙','蛇','马','羊','猴','鸡','狗','猪'];
var LUNAR_MONTH = ['正','二','三','四','五','六','七','八','九','十','冬','腊'];
var LUNAR_DAY = ['','初一','初二','初三','初四','初五','初六','初七','初八','初九','初十','十一','十二','十三','十四','十五','十六','十七','十八','十九','二十','廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十','卅'];
var LUNAR_ONLY_FESTIVALS = { '元宵': true, '七夕': true, '重阳': true, '腊八': true, '除夕': true };


// ==================== 训练模板 ====================
var TRAINING_TEMPLATES = [
  { id: 'push', name: '推日', icon: '💪', desc: 'Chest / Shoulders / Triceps',
    exercises: [{time:'—',content:'平板卧推 4x8'},{time:'—',content:'上斜哑铃推举 4x10'},{time:'—',content:'侧平举 4x12'},{time:'—',content:'绳索下压 3x12'},{time:'—',content:'双杠臂屈伸 3x10'}]},
  { id: 'pull', name: '拉日', icon: '🏋️', desc: 'Back / Biceps',
    exercises: [{time:'—',content:'硬拉 4x6'},{time:'—',content:'引体向上 4x8'},{time:'—',content:'杠铃划船 4x10'},{time:'—',content:'面拉 4x12'},{time:'—',content:'哑铃弯举 3x12'}]},
  { id: 'legs', name: '腿日', icon: '🦵', desc: 'Legs',
    exercises: [{time:'—',content:'深蹲 5x5'},{time:'—',content:'罗马尼亚硬拉 4x8'},{time:'—',content:'腿举 4x10'},{time:'—',content:'腿弯举 4x12'},{time:'—',content:'站姿提踵 4x15'}]},
  { id: 'cardio', name: '有氧/核心', icon: '🏃', desc: 'Cardio / Core',
    exercises: [{time:'—',content:'跑步 30分钟'},{time:'—',content:'平板支撑 3组'},{time:'—',content:'卷腹 4x20'},{time:'—',content:'俄罗斯转体 4x20'},{time:'—',content:'悬垂举腿 3x12'}]}
];


// ==================== GIF 素材列表 ====================
var ALL_GIFS = ["1号.gif","2号.gif","3号.gif","4号.gif","5号.gif","6号.gif","7号.gif","8号.gif","9号.gif","10号.gif","11号.gif","12号.gif","13.gif","14.gif","15.gif","16.gif","17.gif","18.gif","19.gif","21.gif","22.gif","23.gif","24.gif","25.gif","26.gif","27.gif","28.gif","29.gif","30.gif","31.gif","32.gif","33.gif","34.gif","35.gif","36.gif","37.gif","38.gif","39.gif","40.gif","41.gif","42.gif","43.gif","惩戒秩序.gif","等离子.gif","重力.gif","奇异.gif","护盾.gif","恢复.gif","分身.gif","器械.gif","雨天.gif","飞行.gif","变换.gif","冲击.gif"];

// ==================== 语音标签分类规则 ====================
var VOICE_TAG_RULES = [
  { keys: ['开会','报告','需求','prd','评审','周报','方案','审批','汇报','项目','会议','客户','合同','预算','报销'], tag: '工作' },
  { keys: ['上课','考试','作业','论文','复习','背单词','做题','课程','网课','毕业论文','答辩','读书'], tag: '学习' },
  { keys: ['跑步','健身','瑜伽','游泳','打球','篮球','足球','运动','锻炼','训练','马拉松'], tag: '运动' },
  { keys: ['聚餐','电影','约饭','ktv','派对','聚会','逛街','蹦迪','唱k','约会'], tag: '社交' },
  { keys: ['买菜','淘宝','京东','下单','购物','超市','商场','快递','收货'], tag: '购物' },
  { keys: ['医院','体检','挂号','吃药','看病','诊所','牙医','复诊','疫苗'], tag: '健康' },
  { keys: ['高铁','机票','酒店','出行','旅游','旅行','航班','火车','地铁','打车'], tag: '出行' },
  { keys: ['游戏','开黑','steam','switch','ps5','王者','吃鸡','原神','追剧','综艺'], tag: '娱乐' }
];

// ==================== 默认标签色映射 ====================
var DEFAULT_TAG_CLASSES = { '工作':'tg-w', '学习':'tg-s', '生活':'tg-l' };
var TAG_COLORS = { '工作':'tg-w', '学习':'tg-s', '生活':'tg-l' };
var ALL_TAGS = ['工作','学习','生活'];

// ==================== 全局变量声明 ====================
var today = new Date(); today.setHours(0,0,0,0);
var todayKey = dk(today);
var selectedDate = todayKey;
var currentTheme = 'dark';
var _addTag = '工作';
var _editIdx = -1;
var isRecording = false;
var recognition = null;
var voiceUnavailable = false;
var voiceIsRecording = false;
var voiceRecTimer = null;
var pnlY, pnlM;
(function(){ var n = new Date(); pnlY = n.getFullYear(); pnlM = n.getMonth()+1; })();

// ==================== 认证密钥 ====================
var authIsRegister = false;


// ==================== 日期工具函数 ====================
function dk(d) {
  return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
}
function dateKey(d) {
  var y = d.getFullYear();
  var m = String(d.getMonth() + 1).padStart(2, '0');
  var day = String(d.getDate()).padStart(2, '0');
  return y + '-' + m + '-' + day;
}
