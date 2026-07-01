// 语程 — 日历面板模块
// 职责: 日历面板渲染/导航、农历计算、实时时钟、日期选择

// ==================== 农历计算 ====================
// ==================== 农历计算 ====================
var lunarInfo = [
  0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,
  0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,
  0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,
  0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,
  0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,
  0x06ca0,0x0b550,0x15355,0x04da0,0x0a5b0,0x14573,0x052b0,0x0a9a8,0x0e950,0x06aa0,
  0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,
  0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b6a0,0x195a6,
  0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,
  0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x05ac0,0x0ab60,0x096d5,0x092e0,
  0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,
  0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,
  0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,
  0x05aa0,0x076a3,0x096d0,0x04afb,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,
  0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,
  0x14b63,0x09370,0x049f8,0x04970,0x064b0,0x168a6,0x0ea50,0x06aa0,0x1a6c4,0x0aae0,
  0x092e0,0x0d2e3,0x0c960,0x0d557,0x0d4a0,0x0da50,0x05d55,0x056a0,0x0a6d0,0x055d4,
  0x052d0,0x0a9b8,0x0a950,0x0b4a0,0x0b6a6,0x0ad50,0x055a0,0x0aba4,0x0a5b0,0x052b0,
  0x0b273,0x06930,0x07337,0x06aa0,0x0ad50,0x14b55,0x04b60,0x0a570,0x054e4,0x0d160,
  0x0e968,0x0d520,0x0daa0,0x16aa6,0x056d0,0x04ae0,0x0a9d4,0x0a4d0,0x0d150,0x0f252,
  0x0d520
];

var GAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
var ZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
var ZODIAC = ['鼠','牛','虎','兔','龙','蛇','马','羊','猴','鸡','狗','猪'];
var LUNAR_MONTH = ['正','二','三','四','五','六','七','八','九','十','冬','腊'];
var LUNAR_DAY = [
  '','初一','初二','初三','初四','初五','初六','初七','初八','初九','初十',
  '十一','十二','十三','十四','十五','十六','十七','十八','十九','二十',
  '廿一','廿二','廿三','廿四','廿五','廿六','廿七','廿八','廿九','三十','卅'
];

function lYearDays(y) {
  var sum = 348;
  for (var i = 0x8000; i > 0x8; i >>= 1) {
    sum += (lunarInfo[y - 1900] & i) ? 1 : 0;
  }
  return sum + leapDays(y);
}

function leapMonth(y) {
  return lunarInfo[y - 1900] & 0xf;
}

function leapDays(y) {
  if (leapMonth(y)) {
    return (lunarInfo[y - 1900] & 0x10000) ? 30 : 29;
  }
  return 0;
}

function monthDays(y, m) {
  return (lunarInfo[y - 1900] & (0x10000 >> m)) ? 30 : 29;
}

function solarToLunar(y, m, d) {
  var i, leap, temp, offset;
  
  // Days offset from 1900-01-31 (lunar 1900-01-01)
  if (y < 1900 || y > 2100) return null;
  
  offset = 0;
  for (i = 1900; i < y; i++) {
    offset += lYearDays(i);
  }
  for (i = 1; i < m; i++) {
    offset += solarMonthDays(y, i);
  }
  offset += d - 31;
  
  var lunarYear, lunarMonth, lunarDay, isLeap = false;
  for (lunarYear = 1900; lunarYear < 2101 && offset > 0; lunarYear++) {
    temp = lYearDays(lunarYear);
    offset -= temp;
  }
  if (offset < 0) {
    offset += lYearDays(--lunarYear);
  }
  
  leap = leapMonth(lunarYear);
  for (lunarMonth = 1; lunarMonth < 13 && offset > 0; lunarMonth++) {
    if (leap > 0 && lunarMonth === (leap + 1) && !isLeap) {
      --lunarMonth;
      isLeap = true;
      temp = leapDays(lunarYear);
    } else {
      temp = monthDays(lunarYear, lunarMonth);
    }
    if (isLeap && lunarMonth === (leap + 1)) isLeap = false;
    offset -= temp;
  }
  
  if (offset === 0 && leap === lunarMonth && !isLeap) {
    if (isLeap) { isLeap = false; }
    else { isLeap = true; --lunarMonth; }
  }
  
  if (offset < 0) {
    offset += isLeap ? leapDays(lunarYear) : monthDays(lunarYear, lunarMonth);
    isLeap = false;
  }
  
  lunarDay = offset + 1;
  
  var yearOffset = (lunarYear - 4) % 60;
  if (yearOffset < 0) yearOffset += 60;
  var yearName = GAN[yearOffset % 10] + ZHI[yearOffset % 12];
  var zodiac = ZODIAC[(lunarYear - 4) % 12];
  var monthName = (isLeap ? '闰' : '') + LUNAR_MONTH[lunarMonth - 1];
  var dayName = lunarDay <= 30 ? LUNAR_DAY[lunarDay] : '卅';
  
  return {
    lunarYear: lunarYear, lunarMonth: lunarMonth, lunarDay: lunarDay,
    isLeap: isLeap, yearName: yearName, monthName: monthName,
    dayName: dayName, zodiac: zodiac
  };
}

function solarMonthDays(y, m) {
  if (m === 2) {
    return ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0) ? 29 : 28;
  }
  return [31,0,31,30,31,30,31,31,30,31,30,31][m - 1];
}

function getLunarFestival(lunarMonth, lunarDay, isLeap) {
  if (isLeap) return null;
  
  // 春节（正月初一）
  if (lunarMonth === 1 && lunarDay === 1) return { name: '春节', cssClass: 'festival-spring' };
  // 元宵（正月十五）
  if (lunarMonth === 1 && lunarDay === 15) return { name: '元宵', cssClass: 'festival-yuanxiao' };
  // 端午（五月初五）
  if (lunarMonth === 5 && lunarDay === 5) return { name: '端午', cssClass: 'festival-duanwu' };
  // 七夕（七月初七）
  if (lunarMonth === 7 && lunarDay === 7) return { name: '七夕', cssClass: 'festival-qixi' };
  // 中秋（八月十五）
  if (lunarMonth === 8 && lunarDay === 15) return { name: '中秋', cssClass: 'festival-zhongqiu' };
  // 重阳（九月初九）
  if (lunarMonth === 9 && lunarDay === 9) return { name: '重阳', cssClass: 'festival-chongyang' };
  // 腊八（腊月初八）
  if (lunarMonth === 12 && lunarDay === 8) return { name: '腊八', cssClass: 'festival-laba' };
  
  return null;
}

// 农历特有节日（不在法定假日列表中的）：元宵、七夕、重阳、腊八、除夕
var LUNAR_ONLY_FESTIVALS = { '元宵': true, '七夕': true, '重阳': true, '腊八': true, '除夕': true };

function getLunarDateForCell(key) {
  var parts = key.split('-');
  if (parts.length !== 3) return null;
  var y = parseInt(parts[0]), m = parseInt(parts[1]), d = parseInt(parts[2]);
  var lunar = solarToLunar(y, m, d);
  if (!lunar) return null;
  
  // 检查除夕（腊月最后一天）
  var fest = getLunarFestival(lunar.lunarMonth, lunar.lunarDay, lunar.isLeap);
  if (!fest && lunar.lunarMonth === 12 && !lunar.isLeap) {
    // 检查是否是腊月最后一天（除夕）
    var daysIn12 = monthDays(lunar.lunarYear, 12);
    if (lunar.lunarDay === daysIn12) {
      fest = { name: '除夕', cssClass: 'festival-chuxi' };
    }
  }
  
  var hi = getHolidayInfo(key);
  var hasStatHoliday = hi && hi.type === 'holiday';
  
  if (fest) {
    // 春节始终显示在农历日期中
    if (fest.name === '春节') {
      return { text: '春节', cssClass: 'lunar-date festival ' + fest.cssClass };
    }
    // 如果已有法定假日 badge，且不是农历特有节日，则不重复标注
    if (hasStatHoliday && !LUNAR_ONLY_FESTIVALS[fest.name]) {
      return { text: lunar.dayName, cssClass: 'lunar-date' };
    }
    return { text: fest.name, cssClass: 'lunar-date festival ' + fest.cssClass };
  }
  
  return { text: lunar.dayName, cssClass: 'lunar-date' };
}

// ==================== 日历面板渲染与交互 ====================
// ===== Calendar Panel =====
function openCalendar() {
  document.getElementById('calPnl').classList.add('on');
  document.getElementById('calOvl').classList.add('on');
  renderPnlCal();
  renderUpcoming();
}
function closeCalendar() {
  document.getElementById('calPnl').classList.remove('on');
  document.getElementById('calOvl').classList.remove('on');
}
function pnlNav(dir) {
  pnlM += dir;
  if (pnlM < 1) { pnlM = 12; pnlY--; }
  if (pnlM > 12) { pnlM = 1; pnlY++; }
  renderPnlCal();
}
function renderPnlCal() {
  document.getElementById('pnlMLbl').textContent = pnlY+'年 '+pnlM+'月';
  var el = document.getElementById('pnlDays');
  var fd = new Date(pnlY, pnlM-1, 1);
  var ld = new Date(pnlY, pnlM, 0);
  var sd = fd.getDay();
  var td = ld.getDate();
  var pl = new Date(pnlY, pnlM-1, 0).getDate();

  var h = '';
  for (var i = sd-1; i >= 0; i--) {
    var d = pl - i;
    h += '<button class="pnl-dbtn om" onclick="selDate('+pnlY+','+(pnlM-1)+','+d+')">'+d+'</button>';
  }
  for (var d=1; d<=td; d++) {
    var dk = pnlY+'-'+String(pnlM).padStart(2,'0')+'-'+String(d).padStart(2,'0');
    var cls = 'pnl-dbtn';
    if (dk===todayKey) cls += ' tdy';
    if (dk===selectedDate) cls += ' sel';
    var he = (events[dk] && events[dk].length > 0);
    h += '<button class="'+cls+'" onclick="selDate('+pnlY+','+pnlM+','+d+')">'+d+(he?'<span class="dot"></span>':'')+'</button>';
  }
  var rem = 42 - (sd + td);
  for (var d=1; d<=rem; d++) {
    h += '<button class="pnl-dbtn om" onclick="selDate('+pnlY+','+(pnlM+1)+','+d+')">'+d+'</button>';
  }
  el.innerHTML = h;
}
function selDate(y,m,d) {
  selectedDate = y+'-'+String(m).padStart(2,'0')+'-'+String(d).padStart(2,'0');
  pnlY = y; pnlM = m;
  updateDt();
  closeCalendar();
  renderAll();
}
function renderUpcoming() {
  var c = document.getElementById('upDays');
  var td2 = new Date();
  var r = [];
  for (var i=0; i<14; i++) {
    var d = new Date(td2); d.setDate(d.getDate()+i+1);
    var k = dk(d);
    var n = (events[k]||[]).length;
    if (n>0) r.push({k:k, d:d, n:n});
  }
  if (r.length===0) {
    c.innerHTML = '<div style="padding:12px;text-align:center;color:var(--t3);font-size:12px;">未来两周暂无行程</div>';
    return;
  }
  r = r.slice(0,7);
  var dn = ['周日','周一','周二','周三','周四','周五','周六'];
  c.innerHTML = r.map(function(x){
    var s = (x.d.getMonth()+1)+'/'+x.d.getDate()+' '+dn[x.d.getDay()];
    return '<div class="up-itm" onclick="selUp(\''+x.k+'\')"><span class="up-dt">'+s+'</span><span class="up-cnt">'+x.n+' 个行程</span></div>';
  }).join('');
}
function selUp(dk) {
  selectedDate = dk;
  var p = dk.split('-');
  pnlY = parseInt(p[0]); pnlM = parseInt(p[1]);
  updateDt();
  closeCalendar();
  renderAll();
}
function updateDt() {
  var p = selectedDate.split('-');
  var d = new Date(parseInt(p[0]),parseInt(p[1])-1,parseInt(p[2]));
  var dn = ['星期日','星期一','星期二','星期三','星期四','星期五','星期六'];
  var s = (d.getMonth()+1)+'月'+d.getDate()+'日 '+dn[d.getDay()];
  if (selectedDate===todayKey) s += ' · 今天';
  document.getElementById('liveDate').textContent = s;
}

// ==================== 实时时钟 ====================
// ===== Live Clock =====
function updClock() {
  var n = new Date();
  document.getElementById('liveClock').textContent =
    String(n.getHours()).padStart(2,'0')+':'+String(n.getMinutes()).padStart(2,'0');
}
