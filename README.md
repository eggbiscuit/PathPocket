# PathPocket — 病理问答助手

AI-powered pathology Q&A assistant for doctors and medical students, built with Flutter (Web + Android + iOS).

## 功能特性

- **AI 流式对话** — 逐字打字机效果，支持 Markdown 渲染
- **RAG 知识溯源** — 回答中 `[1]` 引用标记可点击，弹出病理文献原文
- **多会话管理** — 会话历史按今天/昨天/过去 7 天分组，支持重命名与删除
- **智能滚动** — 流式输出时自动跟随，用户上滑查看历史时暂停，"回到最新↓"悬浮按钮
- **操作面板** — 停止生成、重新生成、复制、👍👎 反馈
- **身份认证** — 手机号 + 短信验证码登录（当前为 mock，验证码固定 `123456`）
- **多端适配** — 桌面常驻侧栏，移动端抽屉，响应式布局（600 / 1024 断点）
- **多 Tab 协调** — Web 端跨 Tab 登出/切换用户实时同步（BroadcastChannel）
- **本地持久化** — Drift (SQLite) 多用户隔离存储，切换账号不串数据
- **多模态图像** — 拖拽/粘贴/相册/拍照上传，ROI 区域裁剪，全屏缩放查看
- **深色模式** — system / 浅色 / 深色三挡，随系统自动切换
- **字体缩放** — 四档（小 / 标准 / 大 / 超大），全局生效
- **语音输入** — 按住说话（iOS / Android），zh-CN 识别，结果自动填入输入框
- **网络重连** — 连接失败/超时/5xx 自动重试（最多 2 次），出错后自动显示"重新生成"按钮

## 技术栈

| 层 | 技术 |
|---|---|
| 框架 | Flutter 3.32 + Dart 3 |
| 状态管理 | flutter_riverpod 3.0（`Notifier` + `NotifierProvider.family`） |
| 路由 | go_router 14（auth redirect + 响应式 shell scaffold） |
| 网络 | Dio 5（SSE streaming + CancelToken） |
| 本地数据库 | Drift 2（sqlite3，5 张关系表，`user_id` 列多用户隔离） |
| 鉴权存储 | flutter_secure_storage（移动）/ sessionStorage（Web） |
| Markdown | flutter_markdown_plus（`[N]` → cite:// 链接 → 引用抽屉） |
| 图片输入 | image_picker + file_picker + super_clipboard + super_drag_and_drop |
| 图片处理 | crop_your_image（ROI 裁剪） + photo_view（全屏缩放） |
| 语音输入 | speech_to_text 7（iOS / Android，hold-to-talk，zh-CN） |
| 设置持久化 | shared_preferences（主题模式 + 字体缩放） |

## 本地运行

```bash
# 1. 安装依赖
flutter pub get

# 2. 生成 Drift 代码（首次 / 修改表结构后需要）
dart run build_runner build --delete-conflicting-outputs

# 3. 复制配置文件并填入 API Key
cp lib/core/config.example.dart lib/core/config.dart
# 编辑 lib/core/config.dart，替换 apiKey 值

# 4. 启动（选择目标平台）
flutter run -d chrome          # Web
flutter run -d <android-id>    # Android
flutter run -d <macos>         # macOS
```

> mock 模式下无需真实 API Key。`lib/main.dart` 中 `chatRepositoryProvider` 默认使用 `MockChatRepository`，mock 验证码固定为 `123456`。

## 打包

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 目录结构

```
lib/
├── main.dart                     # 入口：ProviderScope + 异步初始化
├── app.dart                      # MaterialApp.router + 主题
├── core/
│   ├── config.dart               # API endpoint / key（gitignored，见 config.example.dart）
│   ├── theme.dart                # AppColors + AppPalette(ThemeExtension) + AppTextStyles + buildAppTheme()
│   ├── breakpoints.dart          # 响应式断点（600 / 1024）
│   ├── network/sse_parser.dart   # SSE 事件解析（TokenEvent / CitationEvent / DoneEvent）
│   ├── storage/
│   │   ├── app_database.dart     # Drift 数据库定义 + DAO
│   │   └── secure_token_store.dart
│   ├── router/
│   │   ├── app_router.dart       # GoRouter + auth redirect
│   │   └── shell_scaffold.dart   # 桌面侧栏 / 移动抽屉
│   └── platform/tab_sync.dart   # BroadcastChannel（Web 多 Tab 协调）
└── features/
    ├── auth/                     # 登录模块（User / Repository / Provider / Screen）
    ├── conversations/            # 会话列表模块
    ├── image_input/              # 图像输入（picker / uploader / ROI cropper / viewer）
    ├── settings/                 # 设置模块（主题 / 字体缩放）
    └── chat/                     # 聊天核心
        ├── data/chat_repository.dart   # abstract + OpenAI（retry） + Mock 实现
        ├── domain/message.dart         # Message / Citation / ImageAttachment / Feedback
        └── presentation/
            ├── chat_provider.dart      # ChatNotifier.family（stop/regenerate/Drift 持久化）
            ├── chat_screen.dart        # 主聊天界面（消息列表 + 思考条 + 跳转 FAB）
            ├── chat_input_bar.dart     # 底部输入栏（文本/图片/语音/发送，自管 controller）
            ├── message_bubble.dart     # 气泡布局骨架（用户/AI 气泡 + 时间戳 + 图片行）
            ├── message_content.dart    # AI 内容渲染（Markdown + 流式指示器 + 操作按钮行）
            ├── voice_input_button.dart # 按住说话（iOS/Android）
            ├── citation_drawer.dart    # 引用抽屉 state + UI（CitationDrawerHost）
            └── smart_scroll_controller.dart
```

## 开发路线图

- **Phase 1**（已完成）— 认证 + 流式聊天 + 会话历史 + 多用户隔离 + 状态管理地基
- **Phase 2**（已完成）— 多模态图像（拖拽/粘贴/相册/拍照 + ROI 裁剪 + 全屏查看）+ 引用抽屉完整 UI
- **Phase 3**（已完成）— 深色模式 + 字体缩放 + 语音输入（移动端）+ 网络断线重连
- **Phase 4** — 真后端联调（FastAPI）+ Sentry 监控 + 生产打包

## 免责声明

本产品由 AI 生成回答，**仅供学术参考，不构成医疗诊断**。
