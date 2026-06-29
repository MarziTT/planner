// 语程 — 通知系统模块
// 职责: sendNotification、checkReminders、notifiedToday

var notifiedToday = {};       // 去重集合: { 'HH:MM_content': true }
var lastCheckDate = '';       // 用于跨天重置

// 请求通知权限（延迟2秒 + 用户首次交互都触发，但只请求一次）
var permRequested = false;
function requestNotificationPermission() {
  if (!('Notification' in window)) return;
  if (permRequested) return;
  if (Notification.permission === 'granted') {
    notificationGranted = true;
    notificationDenied = false;
    updatePermHint();
    return;
  }
function sendNotification(title, body) {
  if (!notificationGranted) return;
  try {
    new Notification(title, {
      body: body,
      icon: 'icon.svg',
      tag: 'pixel-planner',
      requireInteraction: false
    });
  } catch(e) {
    // 静默处理
  }
function resetDailyNotifyState() {
  var dk = dateKey(new Date());
  if (lastCheckDate !== dk) {
    lastCheckDate = dk;
    notifiedToday = {};
    morningRemindedToday = false;
  }
function checkEventReminders() {
  resetDailyNotifyState();
  if (!notificationGranted) return;

  var now = new Date();
  var currentHour = now.getHours();
  var currentMinute = now.getMinutes();
  var todayEvts = events[todayKey] || [];

  for (var i = 0; i < todayEvts.length; i++) {
    var e = todayEvts[i];
    var t = e.time;
    // 跳过无具体时间的项目（如健身模板的 '—'）
    if (!t || t === '—' || t === '--:--') continue;

    var parts = t.split(':');
    if (parts.length !== 2) continue;
    var eventHour = parseInt(parts[0], 10);
    var eventMinute = parseInt(parts[1], 10);
    if (isNaN(eventHour) || isNaN(eventMinute)) continue;

    // 匹配当前分钟
    if (eventHour === currentHour && eventMinute === currentMinute) {
      var dedupKey = t + '_' + e.content;
      if (notifiedToday[dedupKey]) continue;
      notifiedToday[dedupKey] = true;

      var title = '⏰ 行程提醒 - 语程';
      body = t + ' - ' + e.content;
      sendNotification(title, body);
    }
function initNotifications() {
  if (!('Notification' in window)) return;
  if (Notification.permission === 'granted') {
    notificationGranted = true;
    permRequested = true;
  } else if (Notification.permission === 'denied') {
    notificationDenied = true;
  }
