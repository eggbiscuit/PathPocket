# PathPocket 部署指南

本文档说明如何把 PathPocket 部署上线。前端是 Flutter web（静态文件），后端是 FastAPI + Postgres（Docker 服务），两者通过 HTTP API 通信、各自独立部署。

后端的接口契约见 [`backend/API.md`](backend/API.md)，后端运维细节见 [`backend/README.md`](backend/README.md)。

---

## 架构总览

```
   前端（静态）                          后端（服务器，HTTPS）
┌────────────────────┐   HTTPS/JSON   ┌──────────────────────────┐
│ Flutter web 构建    │ ────────────►  │ FastAPI + Postgres        │
│ GitHub Pages /      │ ◄────────────  │ Docker (api + db)         │
│ Netlify / Vercel    │                │ ngrok / 云主机 暴露公网     │
└────────────────────┘                └──────────────────────────┘
```

两条独立的部署线：
- **后端**：必须跑在能执行 Python 进程的服务器上，且对外是 **HTTPS**（前端是 HTTPS，浏览器会拦截 HTTPS 页面发往 HTTP 的请求）。
- **前端**：编译成静态文件，可托管在 GitHub Pages 等静态托管。构建时通过 `--dart-define=BACKEND_BASE_URL=...` 注入后端地址。

---

## 一、后端部署

### 1. 配置 `.env`

```bash
cd backend
cp .env.example .env
```

关键变量（完整说明见 `backend/README.md`）：

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | 生产用 Postgres：`postgresql+asyncpg://user:pass@host:5432/db` |
| `JWT_SECRET` | **生产必须改**：`openssl rand -hex 32`。仍为默认值时启动会打 warning |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | 首个管理员。启动时按此创建或提升；ADMIN_PASSWORD 始终是权威值 |
| `BACKEND_BASE_URL` | **本服务的公网地址**，用于拼验证邮件链接。必须是真实用户能访问的 URL |
| `CORS_ORIGINS` | 逗号分隔，**必须包含前端站点域名** |
| `CORS_ORIGIN_REGEX` | 可选，匹配动态来源（如轮换 ngrok 子域），例 `^https://.*\.ngrok\.app$` |
| `SMTP_*` | 邮件发送配置（见下「邮件」一节）；未配置时验证链接打印到控制台 |

### 2. 用 Docker 启动（含 Postgres）

```bash
docker compose up -d --build
```

`docker-compose.yml` 起 `db`（postgres:16）和 `api` 两个服务，api 的 `DATABASE_URL` 已指向容器内 Postgres，数据持久化在 `pgdata` 卷。`.env` 里的变量会被 compose 透传进容器。

> 改了 `.env` 后必须 `docker compose up -d`（重建容器）才会读入新值，`restart` 不会重新读 `.env`。

健康检查：`curl http://localhost:8000/health` → `{"status":"ok"}`，Swagger 在 `/docs`。

### 3. 暴露成公网 HTTPS

前端是 HTTPS，所以后端必须 HTTPS。两种方式：

**A) ngrok（快速 / 原型）**
```bash
ngrok http 8000
# 拿到 https://xxxx.ngrok-free.app，填回 .env 的 BACKEND_BASE_URL，再 docker compose up -d
```
注意：免费版 URL **每次重启都会变**，变了要更新 `BACKEND_BASE_URL` 并重建容器；首次访问有一个 "Visit Site" 拦截页。长期用建议 ngrok 固定域名。

**B) 云主机 / PaaS（生产）**
把 `backend/` 部署到 Railway / Render / VPS，平台提供 HTTPS 域名和托管 Postgres。把该域名填入 `BACKEND_BASE_URL`，把前端域名填入 `CORS_ORIGINS`。

### 4. 邮件（验证链接 + 管理员审批提醒）

注册时后端自动发两封邮件：给新用户的**验证链接**、给 `ADMIN_EMAIL` 的**审批提醒**。配置任一 SMTP 即可。

示例（Private Email）：
```
SMTP_HOST=mail.privateemail.com
SMTP_PORT=587
SMTP_USER=你的邮箱@你的域名
SMTP_PASSWORD=邮箱密码
SMTP_FROM=PathPocket <你的邮箱@你的域名>
```

要点：
- 验证链接 = `BACKEND_BASE_URL/auth/verify-email?token=...`，所以 **`BACKEND_BASE_URL` 必须是公网地址**，否则真实用户点链接打不开（会指向他自己的 localhost）。
- SMTP 认证失败不会让注册失败（已做降级，只打 warning）。
- 新域名邮件易被 Gmail 等判为垃圾邮件；给域名加 SPF/DKIM/DMARC 记录可大幅提升送达率。

### 5. 管理员

启动时 `ADMIN_EMAIL` 对应用户若存在则提升为管理员（并把密码同步为 `ADMIN_PASSWORD`），不存在则创建。种子逻辑只提升、**从不降级**其他管理员。用管理员账号登录即可在前端审批面板通过/拒绝新用户。

---

## 二、前端部署

前端有两种构建：

### A) 演示版（GitHub Pages，纯 mock，无需后端）

`.github/workflows/deploy.yml` 已配置：push 到 `main` 自动构建并部署到 GitHub Pages：

```bash
flutter build web --release --base-href /PathPocket/ --dart-define=USE_MOCK=true
```

- `USE_MOCK=true` → 全程客户端运行（mock 登录 + mock 聊天），任意邮箱 + 6 位以上密码即可登录，`admin@` 前缀为管理员。
- 访问 `https://eggbiscuit.github.io/PathPocket/`
- 首次启用需在仓库 **Settings → Pages** 把 Source 设为 `gh-pages` 分支。

### B) 真实版（连后端）

```bash
flutter build web --release \
  --base-href /你的子路径/ \
  --dart-define=BACKEND_BASE_URL=https://你的后端公网地址
```

把 `build/web/` 部署到任意静态托管（GitHub Pages / Netlify / Vercel）。`--base-href` 取决于托管路径：根域名用 `/`，子路径（如 `用户名.github.io/仓库名/`）用 `/仓库名/`。

> 本地联调：`flutter run -d chrome --web-port 8080 --dart-define=BACKEND_BASE_URL=http://localhost:8000`。端口固定 8080 是因为后端 CORS 白名单里有它。

---

## 三、前后端连接三要点

1. **HTTPS 对 HTTPS**：前端 HTTPS 时后端也必须 HTTPS，否则浏览器拦截混合内容。
2. **CORS**：后端 `CORS_ORIGINS` 必须包含前端的确切来源（含协议和端口）。`allow_origins=["*"]` 与凭证不兼容，需要通配用 `CORS_ORIGIN_REGEX`。
3. **地址注入**：前端不写死后端地址，构建时 `--dart-define=BACKEND_BASE_URL=...` 注入。

---

## 四、上线清单

后端：
- [ ] `JWT_SECRET` 已换成强随机值
- [ ] `DATABASE_URL` 指向生产 Postgres
- [ ] `BACKEND_BASE_URL` 是真实公网 HTTPS 地址
- [ ] `CORS_ORIGINS` 含前端域名
- [ ] `ADMIN_EMAIL` / `ADMIN_PASSWORD` 已设
- [ ] SMTP 已配置且测试发信成功
- [ ] `docker compose up -d --build` 后 `/health` 正常、`pytest` 全绿

前端：
- [ ] `--dart-define=BACKEND_BASE_URL` 指向上面的后端地址
- [ ] `--base-href` 与托管路径匹配
- [ ] 部署后能注册 → 收验证邮件 → 点链接 → 管理员审批 → 登录全流程跑通

---

## 五、常见问题

- **真实用户点验证链接打不开** → `BACKEND_BASE_URL` 还是 localhost，改成公网地址并重建容器。
- **登录跨域失败（OPTIONS 400 / CORS error）** → 前端来源没在 `CORS_ORIGINS` 里。
- **改了 `.env` 不生效** → 用 `docker compose up -d` 重建，不要用 `restart`。
- **演示站老用户被旧缓存卡住** → Flutter service worker 缓存了旧版本；无痕窗口可验证，根治需更新缓存策略。
- **Gmail 收不到邮件** → 新域名信誉低被过滤；查垃圾箱，并给域名加 SPF/DKIM/DMARC。
- **ngrok URL 变了** → 免费版每次重启变化，更新 `BACKEND_BASE_URL` 并重建容器，或用固定域名。
