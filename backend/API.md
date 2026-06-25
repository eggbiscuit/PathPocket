# PathPocket 认证后端 — API 契约

供集成方对接的、与具体前端框架无关的 REST 契约。交互式版本见运行时的 Swagger UI：`GET /docs`（OpenAPI JSON：`/openapi.json`）。

## 基本约定

- **Base URL**：由部署决定，例如 `http://localhost:8000`（本地）或你的生产域名。
- **请求/响应体**：JSON（`Content-Type: application/json`）。
- **鉴权**：受保护接口需带 `Authorization: Bearer <access_token>`。
- **时间**：所有时间戳为 ISO 8601、UTC（带时区）。
- **统一错误体**：所有业务错误返回如下结构，HTTP 状态码见各接口。
  ```json
  { "detail": { "code": "PENDING_APPROVAL", "message": "账号正在等待管理员审批" } }
  ```
  集成方应**按 `detail.code` 分支**驱动 UI，`message` 仅用于兜底展示。
- **字段校验失败**（如邮箱格式非法、密码过短）由框架返回 **422**，体为 FastAPI 默认的 `{"detail": [ ... ]}` 列表（与上面的业务错误结构不同）。

## 双重门禁（登录核心规则）

登录成功（拿到 token）必须同时满足：

1. `email_verified == true`（已点验证邮件链接），**且**
2. `status == "approved"`（管理员已审批通过）。

任一不满足都返回 **403**，并用不同 `code` 区分，集成方据此展示不同界面：

| code | 含义 | 建议 UI |
|------|------|---------|
| `EMAIL_NOT_VERIFIED` | 邮箱未验证 | 提示去邮箱点验证链接 |
| `PENDING_APPROVAL` | 等待管理员审批 | 待审批页 + “重新检查”按钮（重新调 login 探测） |
| `REJECTED` | 审批被拒 | 提示联系管理员 |

## 数据模型 `UserOut`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 主键，形如 `u_<hex>` |
| `email` | string | 登录标识，唯一 |
| `display_name` | string \| null | 显示名（注册不填时取邮箱 `@` 前缀） |
| `role` | `"user"` \| `"admin"` | 角色 |
| `status` | `"pending"` \| `"approved"` \| `"rejected"` | 审批状态 |
| `email_verified` | bool | 邮箱是否已验证 |
| `created_at` | datetime | 创建时间 |
| `approved_at` | datetime \| null | 审批通过时间 |

---

## 认证接口 `/auth`

### POST /auth/register
注册新用户（创建为 `status=pending, email_verified=false`，并发送验证邮件；未配 SMTP 时验证链接打印到后端控制台）。

请求体：
```json
{ "email": "user@example.com", "password": "至少6位", "display_name": "可选，≤64字" }
```
- `email`：`EmailStr` 校验，格式非法 → **422**。
- `password`：长度 6–128，越界 → **422**。

成功 **201**：
```json
{
  "message": "注册成功，请查收验证邮件，并等待管理员审批。",
  "user": { "...": "UserOut" }
}
```
错误：
| 状态 | code | 场景 |
|------|------|------|
| 409 | `EMAIL_EXISTS` | 邮箱已注册 |
| 422 | — | 邮箱格式非法 / 密码长度越界 |

### GET /auth/verify-email?token=...
点击验证邮件里的链接时访问。校验一次性 verify token（48h 有效），把 `email_verified` 置 true（状态仍为 `pending`，等管理员）。返回一个 **HTML 页面**（非 JSON），用于浏览器直接展示“验证成功”。

错误：`token` 无效/过期 → **401** `INVALID_TOKEN`；用户不存在 → **404** `USER_NOT_FOUND`。

### POST /auth/login
请求体：
```json
{ "email": "user@example.com", "password": "..." }
```
成功 **200** → `TokenOut`：
```json
{
  "access_token": "<jwt>",
  "refresh_token": "<jwt>",
  "token_type": "bearer",
  "user": { "...": "UserOut" }
}
```
错误：
| 状态 | code | 场景 |
|------|------|------|
| 401 | `INVALID_CREDENTIALS` | 邮箱不存在或密码错误 |
| 403 | `EMAIL_NOT_VERIFIED` | 邮箱未验证 |
| 403 | `PENDING_APPROVAL` | 等待审批 |
| 403 | `REJECTED` | 审批被拒 |

### POST /auth/refresh
用 refresh token 换一套新 token。请求体：
```json
{ "refresh_token": "<jwt>" }
```
成功 **200** → `TokenOut`（同 login）。错误：token 非法 → **401** `INVALID_TOKEN`；账号非 approved → **403** `PENDING_APPROVAL`。

### GET /auth/me
需 `Authorization: Bearer <access_token>`。成功 **200** → `UserOut`。
错误：无 token → **401** `NOT_AUTHENTICATED`；token 非法/用户不存在 → **401** `INVALID_TOKEN`。

---

## 管理员接口 `/admin`

整个 `/admin` 前缀受 `require_admin` 保护：需带 admin 用户的 `Authorization: Bearer <access_token>`。非管理员 → **403** `FORBIDDEN`；未带 token → **401** `NOT_AUTHENTICATED`。

### GET /admin/users?status=pending
列出用户，按 `created_at` 倒序。可选 `status` 过滤（`pending` / `approved` / `rejected`），不传则返回全部。成功 **200** → `UserOut[]`。

### POST /admin/users/{user_id}/approve
把目标用户置 `status=approved`、`approved_at=now`。成功 **200** → `UserOut`。用户不存在 → **404** `USER_NOT_FOUND`。

### POST /admin/users/{user_id}/reject
把目标用户置 `status=rejected`。成功 **200** → `UserOut`。用户不存在 → **404** `USER_NOT_FOUND`。

---

## 首个管理员（admin 种子）

后端启动时读取环境变量 `ADMIN_EMAIL` / `ADMIN_PASSWORD`：
- 若该邮箱用户**已存在** → 提升为 `role=admin, status=approved, email_verified=true`；
- 若**不存在** → 用这对邮箱/密码创建首个管理员。

用这个账号登录即可调用 `/admin/*` 审批其他注册用户。

## 错误码总表

| code | 典型状态 | 含义 |
|------|----------|------|
| `EMAIL_EXISTS` | 409 | 注册邮箱已存在 |
| `INVALID_CREDENTIALS` | 401 | 登录邮箱/密码错误 |
| `EMAIL_NOT_VERIFIED` | 403 | 邮箱未验证 |
| `PENDING_APPROVAL` | 403 | 等待管理员审批 |
| `REJECTED` | 403 | 审批被拒 |
| `INVALID_TOKEN` | 401 | token 非法/过期/类型不符/用户不存在 |
| `NOT_AUTHENTICATED` | 401 | 受保护接口未带 token |
| `FORBIDDEN` | 403 | 需要管理员权限 |
| `USER_NOT_FOUND` | 404 | 目标用户不存在 |
| （无 code，框架默认） | 422 | 请求体字段校验失败（邮箱格式、密码长度等） |
