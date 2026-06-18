# Pixel Planner v3.2

像素风日程管理应用，Android WebView APK + Python Flask 后端。

## 技术栈

- **前端**: HTML5/CSS/JS，WebView 容器加载
- **后端**: Python Flask + SQLite（本地）/ PostgreSQL（Railway）
- **构建**: Gradle（Android APK）

## 项目结构

```
PixelPlanner/
├── pixel_calendar_new.html   # 主应用页面
├── splash.html               # 启动闪屏
├── server.py                 # Flask API 后端（16 个端点，5 张数据表）
├── requirements.txt          # Python 依赖
├── Procfile                  # Railway 部署配置
├── www/                      # WebView 静态资源
├── android/                  # Android 项目
└── gifs/                     # 像素风 GIF 素材
```

## 功能

- 日程与事件管理
- 语音 AI 标签识别
- 动态标签系统
- 用户注册/登录
- AI 身份信息采集
- 多主题切换（solar / dark / warm / clean / brutal）

## 部署

后端部署于 Railway，前端以 WebView 方式打包为 Android APK，API 自动连接 Railway 后端。

## 开发

```bash
# 启动本地后端
python server.py

# 构建 APK
cd android && gradlew assembleDebug
```
