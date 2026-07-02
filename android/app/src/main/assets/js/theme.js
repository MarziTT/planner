// 语程 — 主题管理模块
// 职责: applyTheme、setTh、Kamen特效（粒子/GIF）、randomGif、gifBgHtml

function applyTheme(th) {
  document.documentElement.setAttribute('data-theme', th);
  var opts = document.querySelectorAll('#thGrid .th-opt');
  opts.forEach(function(o) { o.classList.toggle('sel', o.getAttribute('data-th') === th); });

  // Kamen effects
  var gal = document.getElementById('gifGallery');
  if (th === 'kamen') {
    if (gal) { gal.style.display = 'flex'; renderKamenGifs(); }
    initKamenParticles();
    var fl = document.querySelector('#fabBtn .fab-lbl');
    if (!fl) { fl = document.createElement('span'); fl.className = 'fab-lbl'; document.getElementById('fabBtn').appendChild(fl); }
    fl.textContent = 'HENSHIN!';
  } else {
    if (gal) gal.style.display = 'none';
    cleanupKamenParticles();
    var fl2 = document.querySelector('#fabBtn .fab-lbl');
    if (fl2) fl2.remove();
  }

  // Ocean wave effects
  var waveC = document.getElementById('waveBg');
  if (th === 'ocean') {
    if (!waveC) {
      waveC = document.createElement('div'); waveC.id = 'waveBg';
      waveC.innerHTML = '<div class="wave wave1"></div><div class="wave wave2"></div><div class="wave wave3"></div>';
      document.body.appendChild(waveC);
    } else { waveC.style.display = 'block'; }
  } else {
    if (waveC) waveC.style.display = 'none';
  }

  // Forest leaf effects
  var leafC = document.getElementById('leafBg');
  if (th === 'forest') {
    if (!leafC) {
      leafC = document.createElement('div'); leafC.id = 'leafBg';
      document.body.appendChild(leafC);
      for (var i = 0; i < 15; i++) {
        var leaf = document.createElement('div'); leaf.className = 'leaf';
        leaf.style.left = Math.random() * 100 + '%';
        leaf.style.animationDelay = Math.random() * 8 + 's';
        leaf.style.animationDuration = (6 + Math.random() * 8) + 's';
        leafC.appendChild(leaf);
      }
    } else { leafC.style.display = 'block'; }
  } else {
    if (leafC) leafC.style.display = 'none';
  }

  // Re-render cards
  if (typeof renderAll === 'function') renderAll();
}

function setTh(th) {
  currentTheme = th;
  try { localStorage.setItem(THEME_KEY, th); } catch(e) {}
  apiSaveSettings({ theme: th }).catch(function(){});
  applyTheme(th);
}

// Kamen GIFs
var ALL_GIFS = ["1\u53f7.gif", "2\u53f7.gif", "3\u53f7.gif", "4\u53f7.gif", "5\u53f7.gif", "6\u53f7.gif", "7\u53f7.gif", "8\u53f7.gif", "9\u53f7.gif", "10\u53f7.gif", "11\u53f7.gif", "12\u53f7.gif", "13.gif", "14.gif", "15.gif", "16.gif", "17.gif", "18.gif", "19.gif", "21.gif", "22.gif", "23.gif", "24.gif", "25.gif", "26.gif", "27.gif", "28.gif", "29.gif", "30.gif", "31.gif", "32.gif", "33.gif", "34.gif", "35.gif", "36.gif", "37.gif", "38.gif", "39.gif", "40.gif", "41.gif", "42.gif", "43.gif", "\u60e9\u6212\u79e9\u5e8f.gif", "\u7b49\u79bb\u5b50.gif", "\u91cd\u529b.gif", "\u5947\u5f02.gif", "\u62a4\u76fe.gif", "\u6062\u590d.gif", "\u5206\u8eab.gif", "\u5668\u68b0.gif", "\u96e8\u5929.gif", "\u98de\u884c.gif", "\u53d8\u6362.gif", "\u51b2\u51fb.gif"];

function renderKamenGifs() {
  var gal = document.getElementById('gifGallery');
  if (!gal) return;
  var a = ALL_GIFS.slice();
  for (var i = a.length - 1; i > 0; i--) { var j = Math.floor(Math.random() * (i+1)); var t = a[i]; a[i] = a[j]; a[j] = t; }
  var n = 3 + Math.floor(Math.random() * 3);
  gal.innerHTML = a.slice(0, n).map(function(g) {
    return '<img src="gifs/' + g + '" loading="lazy" alt="" onerror="this.style.display=\'none\'">';
  }).join('');
}

var kpTimer = null;
function initKamenParticles() {
  cleanupKamenParticles();
  var c = document.getElementById('kamenParticles');
  if (!c) return;
  for (var i = 0; i < 30; i++) {
    var p = document.createElement('div'); p.className = 'kp';
    p.style.left = Math.random() * 100 + '%';
    p.style.animationDelay = Math.random() * 5 + 's';
    p.style.animationDuration = (4 + Math.random() * 6) + 's';
    c.appendChild(p);
  }
}
function cleanupKamenParticles() {
  var c = document.getElementById('kamenParticles');
  if (c) c.innerHTML = '';
}

// ===== Kamen GIF helpers =====
function randomGif() {
  var paths = ["gifs/1号.gif","gifs/2号.gif","gifs/3号.gif","gifs/4号.gif","gifs/5号.gif","gifs/6号.gif","gifs/7号.gif","gifs/8号.gif","gifs/9号.gif","gifs/10号.gif","gifs/11号.gif","gifs/12号.gif","gifs/13.gif","gifs/14.gif","gifs/15.gif","gifs/16.gif","gifs/17.gif","gifs/18.gif","gifs/19.gif","gifs/21.gif","gifs/22.gif","gifs/23.gif","gifs/24.gif","gifs/25.gif","gifs/26.gif","gifs/27.gif","gifs/28.gif","gifs/29.gif","gifs/30.gif","gifs/31.gif","gifs/32.gif","gifs/33.gif","gifs/34.gif","gifs/35.gif","gifs/36.gif","gifs/37.gif","gifs/38.gif","gifs/39.gif","gifs/40.gif","gifs/41.gif","gifs/42.gif","gifs/43.gif","gifs/惩戒秩序.gif","gifs/等离子.gif","gifs/重力.gif","gifs/奇异.gif","gifs/护盾.gif","gifs/恢复.gif","gifs/分身.gif","gifs/器械.gif","gifs/雨天.gif","gifs/飞行.gif","gifs/变换.gif","gifs/冲击.gif","gifs/20.gif"];
  return paths[Math.floor(Math.random() * paths.length)];
}

function gifBgHtml() {
  if (document.documentElement.getAttribute('data-theme') !== 'kamen') return '';
  return '<img class="card-gif-bg" src="'+randomGif()+'" alt="">';
}

// ===== 初始化主题 =====
// ===== Theme init =====
try { currentTheme = localStorage.getItem(THEME_KEY) || 'dark'; } catch(e) { currentTheme = 'dark'; }
apiGetSettings().then(function(s) { if (s && s.theme && s.theme !== currentTheme) { currentTheme = s.theme; applyTheme(currentTheme); } }).catch(function(){});
applyTheme(currentTheme);

