# PathPocket 认证后端

FastAPI 实现的独立认证服务：邮箱注册 + 邮箱验证 + 管理员审批后才能登录，签发 JWT（access / refresh）。API 契约见 [API.md](./API.md)；运行后可访问 Swagger：`/docs`。

## 技术栈

- FastAPI + Uvicorn（async）
- SQLAlchemy 2.0（async）— 开发用 SQLite，生产用 PostgreSQL（同一套 ORM）
- Pydantic v2（`EmailStr` 校验）、passlib[bcrypt]（密码哈希）、python-jose（JWT）
- pydantic-settings（读 `.env`）

## 配置（`.env`）

复制样例后填写，**真实 `.env` 不要提交**：

```bash
cp .env.example .env
```

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | 开发 `sqlite+aiosqlite:///./pathpocket.db`；生产 `postgresql+asyncpg://user:pass@host:5432/db` |
| `JWT_SECRET` | **生产必须改**。用 `openssl rand -hex 32` 生成；仍为默认值时启动会打 warning |
| `ACCESS_TOKEN_EXPIRE_MINUTES` / `REFRESH_TOKEN_EXPIRE_DAYS` | token 有效期 |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | 首个管理员，启动时按此创建或提升（见下） |
| `BACKEND_BASE_URL` | 本服务的公网地址，用于拼验证邮件链接 |
| `CORS_ORIGINS` | 逗号分隔的允许来源，**必须包含前端站点域名**（如 `https://smartpath-evidence.site.ngrok.app`） |
| `CORS_ORIGIN_REGEX` | 可选。匹配动态来源（如轮换的 ngrok 子域），例 `^https://.*\.ngrok\.app$`；留空禁用 |
| `SMTP_*` | 可选。未配置时验证邮件链接打印到控制台 |

> CORS 注意：`allow_origins=["*"]` 与 `allow_credentials=True` 不兼容；需要通配时用 `CORS_ORIGIN_REGEX`。

## 本地运行

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload      # http://localhost:8000/docs
```

启动时会自动建表并播种管理员（见下）。

## Docker（含 Postgres）

```bash
# .env 里设好 JWT_SECRET / ADMIN_EMAIL / ADMIN_PASSWORD / CORS_ORIGINS（docker-compose 会读取）
docker-compose up --build
```

`docker-compose.yml` 起两个服务：`db`（postgres:16）和 `api`，api 的 `DATABASE_URL` 已指向 compose 内的 postgres，数据持久化在 `pgdata` 卷。

## 首个管理员

启动时读 `ADMIN_EMAIL` / `ADMIN_PASSWORD`：该邮箱已存在则提升为
`role=admin, status=approved, email_verified=true`；不存在则创建。用它登录即可审批其他用户（`/admin/*`，见 API.md）。

## 测试

```bash
pytest        # 覆盖：无效邮箱 422、未验证/待审批/被拒登录 403、审批后登录成功、admin 鉴权
```

## 手测流程（Swagger `/docs` 或 curl）

1. 无效邮箱 `POST /auth/register` → **422**。
2. 有效注册 → **201**，控制台打印验证链接。
3. 访问该 `GET /auth/verify-email?token=...` → 邮箱验证成功。
4. 此时 `POST /auth/login` → **403** `PENDING_APPROVAL`。
5. 用 admin 账号登录拿 token → `POST /admin/users/{id}/approve`。
6. 再 `POST /auth/login` → **200**，拿到 `access_token` / `refresh_token`。

## 客户端对接

Flutter 客户端构建时通过 `--dart-define` 指向本服务：

```bash
flutter run -d chrome --dart-define=BACKEND_BASE_URL=https://<本服务地址>
```
