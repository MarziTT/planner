# Pixel Planner

Pixel Planner 是一个像素风日程管理应用，包含静态前端、Flask API 后端和 Capacitor Android 打包工程。应用支持账号登录、日程和标签管理、待办事项、主题切换、通知提醒、语音识别代理和热更新文件分发。

## 技术栈

- 前端：HTML / CSS / JavaScript，入口位于 `www/splash.html`，主应用为 `www/pixel_calendar_new.html`
- 后端：Python Flask + SQLite，本地默认数据库为 `data/pixel_planner.db`
- 云端：设置 `DATABASE_URL` 后使用 PostgreSQL
- Android：Capacitor + Gradle

## 常用命令

```bash
npm run start
npm run check
npm run android:debug
```

也可以直接启动后端：

```bash
python server.py
```

默认 API 地址为 `http://localhost:5000`。部署到 Railway 等平台时，请设置 `DATABASE_URL`，并按需设置 `TENCENT_SECRET_ID` / `TENCENT_SECRET_KEY` 以启用语音识别代理。

## 目录结构

```text
PixelPlanner/
├── server.py                 # Flask API 服务
├── requirements.txt          # Python 依赖
├── package.json              # 项目脚本和 Capacitor 依赖
├── www/                      # Web 前端资源
│   ├── splash.html
│   ├── pixel_calendar_new.html
│   ├── sw.js
│   └── js/
├── android/                  # Android 工程
├── data/                     # 本地 SQLite 数据
└── gifs/                     # 像素风 GIF 素材
```

## 说明

- 新账号密码会以 PBKDF2 哈希存储；旧明文账号会在下次成功登录后自动迁移。
- Service Worker 预缓存入口已对齐为 `pixel_calendar_new.html`。
- `node_modules`、构建日志、Gradle 临时文件、APK 和本地数据库默认不纳入版本控制。
