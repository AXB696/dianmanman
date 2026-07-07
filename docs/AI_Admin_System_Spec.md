# Admin 后台管理系统需求文档（AI-Readable）

> 本文档用于指导 AI 分段实现 电满满 充电站管理后台。
> 包含：功能需求、API 需求、数据库字段、页面结构、AI 执行分段说明。

---

## 一、项目概述

**项目名**：电满满 管理后台（admin_v2）
**技术栈**：Flutter Web + FastAPI 后端
**目标用户**：平台管理员（admin）、超级管理员（super_admin）
**核心功能**：用户管理、充电行为数据分析、车辆品牌分布、站内公告、电站数据总览

---

## 二、现有系统资产（可直接复用）

### 2.1 后端（backend_v2）

**API Base URL**：`http://localhost:8000/api/v1`

**已有模型**（位于 `backend_v2/app/models/`）：

| 模型 | 文件 | 关键字段 |
|---|---|---|
| User | `user.py` | id, username, nickname, phone, avatar_url, role, created_at |
| Vehicle | `vehicle.py` | id, user_id, brand, model, battery_capacity, energy_consumption, is_default, created_at |
| Favorite | `favorite.py` | id, user_id, station_id, created_at |
| History | `history.py` | id, user_id, station_id, visited_at |

**已有 API 端点**（位于 `backend_v2/app/api/v1/`）：

| 方法 | 路径 | 说明 | 权限 |
|---|---|---|---|
| POST | /auth/register | 用户注册 | 公开 |
| POST | /auth/login | 用户登录 | 公开 |
| POST | /auth/refresh | 刷新 Token | 公开 |
| GET | /users/me | 当前用户信息 | JWT |
| PUT | /users/me | 更新当前用户信息 | JWT |
| GET | /users/me/vehicles | 获取当前用户车辆列表 | JWT |
| POST | /users/me/vehicles | 添加车辆 | JWT |
| PUT | /users/me/vehicles/{id} | 更新车辆 | JWT |
| DELETE | /users/me/vehicles/{id} | 删除车辆 | JWT |
| GET | /favorites | 获取收藏列表 | JWT |
| POST | /favorites | 添加收藏 | JWT |
| DELETE | /favorites/{station_id} | 删除收藏 | JWT |
| GET | /history | 获取历史记录 | JWT |
| POST | /history | 添加历史记录 | JWT |
| DELETE | /history/{id} | 删除历史记录 | JWT |
| GET | /admin/stats | 全局统计数据 | Admin |
| GET | /users | 分页用户列表（支持 username/phone 搜索） | Admin |
| DELETE | /users/{id} | 删除用户 | Admin |
| GET | /stations | 电站列表（支持区域/类型筛选、分页） | 公开 |
| GET | /station/{station_id} | 电站详情 | 公开 |

**数据库**：`backend_v2/data/smart_charge.db`（SQLite）

**认证方式**：JWT Bearer Token
- Access Token：7 天有效期
- Refresh Token：30 天有效期
- role 字段区分：`user` / `admin` / `super_admin`

### 2.2 前端已有项目（admin_v2）

**路径**：`c:\Users\28773\Desktop\Smart Charge\admin_v2\`
**当前状态**：已有登录页 + Dashboard（含 4 张统计卡片）+ 用户管理 Table（搜索/分页/删除）
**包管理**：`dio` + `shared_preferences`

---

## 三、功能需求清单

### 3.1 管理员认证

#### 3.1.1 管理员登录
- **路径**：/
- **功能**：账号 + 密码登录，校验 role ∈ {admin, super_admin}
- **现有状态**：已完成（后端 ✅）

#### 3.1.2 管理员退出
- 点击退出，清除本地 token，返回登录页
- **现有状态**：已完成

#### 3.1.3 权限角色规划

后台系统有两个管理员角色：`admin`（普通管理员）和 `super_admin`（超级管理员）。

**后端依赖**：
- `get_current_admin`：允许 role ∈ {admin, super_admin}
- `get_current_super_admin`：仅允许 role = super_admin

**前端路由守卫**：前端根据 `user['role']` 决定侧边栏是否显示某些菜单项

**功能权限矩阵**：

| 功能 | admin | super_admin |
|---|---|---|
| Dashboard 仪表盘 | ✅ 可查看 | ✅ 可查看 |
| 用户管理（查看/搜索/删除用户） | ✅ 可操作 | ✅ 可操作 |
| 查看指定用户的车辆列表 | ✅ 可操作 | ✅ 可操作 |
| 站内公告（增/删/改/查） | ✅ 可操作 | ✅ 可操作 |
| 电站总览（只读） | ✅ 可查看 | ✅ 可查看 |
| 管理员账号管理（增/删/改密码） | ❌ 不可见 | ✅ 可操作 |
| 新增超级管理员 | ❌ | ✅ 可操作 |
| 删除管理员账号 | ❌ | ✅ 可操作（不可删自己/不可删 super_admin） |
| 修改管理员密码（他人） | ❌ | ✅ 可操作 |
| 修改本人密码 | ✅ 可操作 | ✅ 可操作 |

---

### 3.2 Dashboard（仪表盘）

**路径**：/dashboard

#### 3.2.1 统计卡片（第一行，4 卡片）
| 卡片 | 数据来源 | 说明 |
|---|---|---|
| 👥 用户总数 | GET /admin/stats → user_count | 平台注册总人数 |
| 🚗 车辆总数 | GET /admin/stats → vehicle_count | 平台车辆总注册数 |
| ⭐ 收藏总数 | GET /admin/stats → favorite_count | 所有用户收藏数 |
| 📍 充电记录 | GET /admin/stats → history_count | 所有用户充电历史总数 |

**现有状态**：已完成

#### 3.2.2 用户增长趋势图（第二行）
- **图表类型**：折线图（Flutter charts）
- **X 轴**：最近 30 天（每日）
- **Y 轴**：当日新增注册用户数
- **API**：GET /admin/stats/daily-users
  - 响应：`{"dates": ["2026-04-01", ...], "counts": [3, 5, ...]}`
- **空状态**：无数据时显示"暂无数据"

#### 3.2.3 充电行为分析（第三行左侧，~60% 宽度）
- **图表类型**：柱状图
- **分析维度 1**：每日充电时段分布（0-6h / 6-12h / 12-18h / 18-24h 各时段充电次数）
  - API：GET /admin/stats/charging-by-hour
  - 响应：`{"periods": ["0-6时", "6-12时", "12-18时", "18-24时"], "counts": [12, 45, 67, 23]}`
- **分析维度 2**：热门站点 TOP 10（充电次数最多的站点）
  - API：GET /admin/stats/top-stations?limit=10
  - 响应：`{"stations": [{"station_id": "S001", "name": "光谷站", "count": 156}, ...]}`
  - 站点名称从 station_repo.get_by_id 获取

#### 3.2.4 车辆品牌分布（第三行右侧，~40% 宽度）
- **图表类型**：饼图 / 环形图
- **数据**：平台所有车辆的品牌占比（TOP 8 + 其他）
- **API**：GET /admin/stats/vehicle-brands
  - 响应：`{"brands": [{"brand": "特斯拉", "count": 45, "percent": 22.5}, ...]}`

---

### 3.3 用户管理（/users）

**路径**：/users

#### 3.3.1 用户列表 Table
- **表头**：ID / 用户名 / 昵称 / 手机号 / 角色 / 注册时间 / 车辆数 / 操作
- **功能**：
  - **搜索**：按 username 模糊搜索
  - **手机号筛选**：按 phone 模糊搜索
  - **分页**：每页 20 条，显示总条数
  - **删除**：确认弹窗后删除
  - **查看详情**：点击用户名展开行，显示该用户的车辆列表和最近 5 条充电记录
- **角色标签**：`👑 超级管理员`（红色）/ `👤 管理员`（橙色）/ `👤 普通用户`（蓝色）
- **现有状态**：✅ 基础 Table + 车辆数列 + 详情展开（段4已完成）

---

### 3.4 管理员账号管理（/admins）（仅 super_admin）

**路径**：/admins

#### 3.4.1 管理员列表 Table
- **表头**：ID / 用户名 / 昵称 / 手机号 / 角色 / 创建时间 / 操作
- **角色**：仅显示 role=admin 或 role=super_admin 的账号
- **操作**：修改密码、删除（删除后该 admin 需重新注册）
- **注意**：不可删除自己；不可删除 super_admin 账号

#### 3.4.2 修改管理员密码
- **表单**：输入新密码 + 确认密码
- **API**：PUT /admin/users/{user_id}/password（body: new_password）

#### 3.4.3 新增管理员
- **API**：POST /admin/users
  - Request body: `{username, password, nickname, phone, role: "admin"}`
  - Response: `{id, username, nickname, role, created_at}`

#### 3.4.4 删除管理员
- **API**：DELETE /admin/users/{user_id}
- **限制**：
  - 不可删除自己
  - 不可删除 super_admin（role=super_admin 的账号不可删除）

---

### 3.5 站内公告（/announcements）

**路径**：/announcements

#### 3.5.1 公告列表
- **Table**：ID / 标题 / 内容摘要 / 发布时间 / 状态（草稿/已发布） / 操作
- **API**：GET /admin/announcements（支持分页）
- **状态**：`draft`（草稿）/ `published`（已发布）

#### 3.5.2 新增公告
- **表单字段**：
  - 标题（必填，最多 50 字）
  - 内容（必填，支持多行文本，最多 500 字）
  - 状态（radio：草稿 / 立即发布）
- **API**：POST /admin/announcements（body: title, content, status）

#### 3.5.3 编辑公告
- **API**：PUT /admin/announcements/{id}（body: title, content, status）

#### 3.5.4 删除公告
- **API**：DELETE /admin/announcements/{id}

#### 3.5.5 App 端展示
- 用户打开 App 时，若有 `status=published` 且 `created_at` 在 7 天内的公告，在首页顶部展示滚动公告栏
- App 端 API：GET /announcements/latest
  - 响应：`{announcements: [{id, title, content, created_at}, ...]}`

---

### 3.6 电站数据总览（/stations）

**路径**：/stations

#### 3.6.1 电站列表（只读）
- **表头**：电站ID / 名称 / 区域 / 类型 / 总桩数 / 功率等级 / 地址
- **功能**：
  - **区域筛选**：下拉选择（汉口 / 武昌 / 汉阳 / 全部）
  - **类型筛选**：下拉选择（ultra / fast / slow / destination / fleet / swap / 全部）
  - **搜索**：按电站名称或地址关键字搜索
  - **分页**：每页 20 条
- **数据来源**：调用 GET /stations（公开接口）

#### 3.6.2 电站详情弹窗
- 点击"查看详情"，弹出 Modal 显示：
  - 完整地址、经纬度、开放时间
  - 充电价格（分段计费）
  - 电站图片（若 station_data 中有）

---

### 3.7 系统设置（/settings）（可选，本期不做）

---

## 四、后端 API 扩展清单

> 以下为实现上述功能需要**新增或扩展**的后端 API。
> **✅ = 已完成实现并验证**

### 4.1 Admin Extended API ✅

**文件**：`backend_v2/app/api/v1/admin_extended.py`

| 方法 | 路径 | 说明 | 权限 | 状态 |
|---|---|---|---|---|
| GET | /admin/stats/daily-users | 最近30天每日新增用户数 | Admin | ✅ |
| GET | /admin/stats/charging-by-hour | 各时段充电次数 | Admin | ✅ |
| GET | /admin/stats/top-stations | 热门站点TOP N | Admin | ✅ |
| GET | /admin/stats/vehicle-brands | 车辆品牌分布 | Admin | ✅ |

### 4.2 公告 API ✅

**ORM**：`backend_v2/app/models/announcement.py`
**Schema**：`backend_v2/app/schemas/announcement.py`

| 方法 | 路径 | 说明 | 权限 | 状态 |
|---|---|---|---|---|
| GET | /admin/announcements | 公告列表（分页） | Admin | ✅ |
| POST | /admin/announcements | 新增公告 | Admin | ✅ |
| PUT | /admin/announcements/{id} | 编辑公告 | Admin | ✅ |
| DELETE | /admin/announcements/{id} | 删除公告 | Admin | ✅ |
| GET | /announcements/latest | App端获取最新公告（7天内已发布） | JWT | ✅ |

### 4.3 管理员账号管理 API ✅

**文件**：`backend_v2/app/api/v1/admin_users.py`

| 方法 | 路径 | 说明 | 权限 | 状态 |
|---|---|---|---|---|
| GET | /admin/users | 管理员账号列表 | Super_admin | ✅ |
| POST | /admin/users | 新增管理员 | Super_admin | ✅ |
| PUT | /admin/users/{id}/password | 修改管理员密码 | Admin（本人或super_admin） | ✅ |
| DELETE | /admin/users/{id} | 删除管理员 | Super_admin（不可删自己/不可删super_admin） | ✅ |

### 4.4 权限依赖 ✅

**文件**：`backend_v2/app/core/dependencies.py`
- `get_current_admin`：允许 role ∈ {admin, super_admin}
- `get_current_super_admin`：仅允许 role = super_admin

### 4.5 数据库变更 ✅

**新增表**：`announcements`

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK | 自增 ID |
| title | VARCHAR(50) | 标题 |
| content | VARCHAR(500) | 内容 |
| status | VARCHAR(20) | draft / published |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

**User 表新增字段**：`last_login_at`（DATETIME， nullable）
- 自动迁移：通过 `PRAGMA table_info` 检测列是否存在，若无则 ALTER TABLE

---

## 五、AI 分段执行计划

> 按以下顺序分段实现，每段完成后验证通过再进行下一段。
> 每段为独立可测试的单元。
> **✅ = 已完成**

### 段 1 ✅：后端基础扩展（数据库 + Admin Extended API）

**目标**：后端新增 Announcement 模型 + 5 个 Admin Extended 统计 API
**涉及文件**：
- `backend_v2/app/models/announcement.py`（新建）
- `backend_v2/app/models/user.py`（新增 last_login_at 字段）
- `backend_v2/app/api/v1/admin_extended.py`（新建）
- `backend_v2/app/api/v1/router.py`（更新路由注册）
- `backend_v2/app/core/database.py`（新增自动迁移 `_migrate_users_table`）

**验证方式**：启动后端，`curl` 测试所有新接口返回正确数据

---

### 段 2 ✅：后端公告 CRUD + 管理员账号管理 API

**目标**：公告增删改查 + 管理员账号增删改密码
**涉及文件**：
- `backend_v2/app/schemas/announcement.py`（新建）
- `backend_v2/app/api/v1/announcements.py`（新建）
- `backend_v2/app/api/v1/admin_users.py`（新建）
- `backend_v2/app/api/v1/router.py`（更新路由注册）
- `backend_v2/app/core/dependencies.py`（新增 `get_current_super_admin`）
- `backend_v2/app/schemas/user.py`（修复 UserProfile 允许 None 值）

**验证方式**：`curl` 测试公告 CRUD（admin token）+ 管理员账号 CRUD（super_admin token）

**测试账号**：
| 账号 | 密码 | 角色 |
|---|---|---|
| admin | admin123 | admin |
| admin2 | admin2123 | admin |
| superadmin | superadmin123 | super_admin |

---

### 段 3 ✅：Flutter Web Admin — 基础框架 + Dashboard 图表 ✅

**目标**：Admin Web 项目基础结构 + 带图表的 Dashboard
**涉及文件**：
- `admin_v2/pubspec.yaml`（添加 `fl_chart: 0.69.2`）
- `admin_v2/lib/services/api_client.dart`（新建完整 API Client，含所有 stats API）
- `admin_v2/lib/pages/dashboard_page.dart`（新建，含图表 + 用户管理 Table）
- `admin_v2/lib/main.dart`（重构为路由 + 登录页，移除了内联 Dashboard）

**图表实现**：
- 📈 **折线图**：用户增长趋势（LineChart，`getDailyUsers`）
- 📊 **柱状图**：充电时段分布（BarChart，`getChargingByHour`，4色）
- 🍩 **饼图**：车辆品牌分布（PieChart，`getVehicleBrands`，TOP 8+其他）
- 📋 **横向柱状图**：热门站点 TOP 10（BarChart `horizontal`，`getTopStations`）

**用户管理 Table**（已实现）：
- 角色标签彩色显示：👑 超级管理员（红色）/ 👑 管理员（橙色）/ 👤 用户（蓝色）
- admin/super_admin 不可被删除

**构建命令**：`flutter build web` ✅
**构建产物**：`admin_v2/build/web/` ✅

---

### 段 4 ✅：Flutter Web Admin — 用户管理增强

**目标**：用户列表添加车辆数列、详情展开功能
**涉及文件**：
- `admin_v2/lib/pages/users_page.dart`（新建专用用户管理页，含详情展开）
- `admin_v2/lib/main.dart`（AdminScaffold 侧边栏 + Dashboard+UsersPage 页面切换）
- `admin_v2/lib/services/api_client.dart`（新增 `getUserVehicles`）
- `admin_v2/lib/pages/admin_shell.dart`（侧边栏外壳，已创建但暂未使用）

**功能实现**：
- 用户名/手机号搜索框（双条件筛选）
- 用户角色彩色标签：👑 超级管理员（红色）/ 👑 管理员（橙色）/ 👤 用户（蓝色）
- 点击用户名行展开详情：基本信息卡片 + 车辆列表卡片
- admin/super_admin 不可删除
- 侧边栏导航（Dashboard / 用户管理 / [管理员账号] / [站内公告] / 电站总览）

**验证方式**：`flutter build web` ✅

---

### 段 5 ✅：Flutter Web Admin — 管理员账号管理（/admins）

**目标**：新增管理员账号管理页面（仅 super_admin 可见）
**涉及文件**：
- `admin_v2/lib/pages/admins_page.dart`（新建 ✅）
- `admin_v2/lib/main.dart`（侧边栏注册 ✅）

**路由**：`/admins` → `AdminsPage`（前端路由守卫：role=super_admin 可见）

**实现功能**：
- 管理员列表 Table（ID/用户名/昵称/手机号/角色/创建时间/操作）
- 新增管理员账号（用户名/密码/昵称/手机号/角色）
- 修改管理员密码（弹窗表单：新密码 + 确认密码）
- 删除管理员（确认弹窗，不可删除自己，不可删除 super_admin）
- 密码修改：本人可修改，super_admin 可修改任意管理员

**后端依赖**：已有点对点实现，无需新增 API
**验证方式**：flutter build web ✅

---

### 段 6 ✅：Flutter Web Admin — 站内公告（/announcements）

**目标**：公告列表 + 新增/编辑/删除公告
**涉及文件**：
- `admin_v2/lib/pages/announcements_page.dart`（新建 ✅）
- `admin_v2/lib/main.dart`（侧边栏注册 ✅）

**实现功能**：
- 公告列表（分页，每页 20 条）
- 新增公告（标题 50 字内/内容 500 字内/状态：草稿/立即发布）
- 编辑公告（同新增表单，预填当前值）
- 删除公告（确认弹窗）
- 公告状态标签（草稿=橙色/已发布=绿色）
- **可见性**：admin 和 super_admin 均可操作（后端 API 用 `get_current_admin`）

**验证方式**：flutter build web ✅

---

### 段 7 ✅：Flutter Web Admin — 电站数据总览（/stations）

**目标**：电站只读管理页面（筛选/搜索/分页/详情弹窗）
**涉及文件**：
- `admin_v2/lib/pages/stations_page.dart`（新建 ✅）
- `admin_v2/lib/main.dart`（侧边栏注册 ✅）
- `admin_v2/lib/services/api_client.dart`（新增 `getAdminStations` ✅）
- `backend_v2/app/api/v1/stations.py`（新增 `/admin/stations` 端点 ✅）

**实现功能**：
- 电站列表（ID/名称/区域/类型/总桩数/功率/地址）
- 区域筛选（汉口/武昌/汉阳/全部）
- 类型筛选（ultra/fast/slow/destination/fleet/swap/全部）
- 关键字搜索（电站名称或地址）
- 分页（每页 20 条）
- 点击卡片查看详情弹窗（完整地址/经纬度/营业时间/价格）

**验证方式**：flutter build web ✅

---

### 段 8 ✅：App 端公告展示

**目标**：App 端在首页顶部展示最新公告滚动条
**涉及文件**：
- `app_v2/lib/home.dart`（添加公告状态、获取方法、滚动横幅组件）✅
- `app_v2/lib/services/api_client.dart`（新增 `getLatestAnnouncements`）✅

**实现功能**：
- 首页地图上方显示滚动公告栏（蓝色横幅，点击查看详情弹窗）
- 自动获取最近 7 天内已发布公告（`GET /announcements/latest`）
- 多条公告 PageView 自动轮播，底部页码点指示
- 点击公告展开详情弹窗（标题/内容/状态/时间）
- 获取失败不影响地图和电站展示

---

## 六、关键文件路径索引

### 后端（✅ = 已完成）
| 文件 | 操作 | 状态 |
|---|---|---|
| `backend_v2/app/models/user.py` | 修改：新增 `last_login_at` | ✅ |
| `backend_v2/app/models/announcement.py` | 新建 | ✅ |
| `backend_v2/app/api/v1/admin_extended.py` | 新建 | ✅ |
| `backend_v2/app/api/v1/announcements.py` | 新建 | ✅ |
| `backend_v2/app/api/v1/admin_users.py` | 新建 | ✅ |
| `backend_v2/app/api/v1/router.py` | 修改：注册新路由 | ✅ |
| `backend_v2/app/core/dependencies.py` | 修改：新增 super_admin 依赖 | ✅ |
| `backend_v2/app/core/database.py` | 修改：新增自动迁移函数 | ✅ |
| `backend_v2/app/schemas/announcement.py` | 新建 | ✅ |
| `backend_v2/app/schemas/user.py` | 修改：允许 None 值 | ✅ |
| `backend_v2/app/api/v1/auth.py` | 修改：登录时更新 last_login_at | ✅ |

### Flutter Web Admin（✅ = 已完成）
| 文件 | 操作 | 状态 |
|---|---|---|
| `admin_v2/pubspec.yaml` | 添加 `fl_chart: 0.69.2` | ✅ |
| `admin_v2/lib/services/api_client.dart` | 新建完整 API Client | ✅ |
| `admin_v2/lib/pages/dashboard_page.dart` | 新建（Dashboard+图表+用户管理） | ✅ |
| `admin_v2/lib/main.dart` | 重构（路由+登录，内联代码移至独立文件） | ✅ |
| `admin_v2/lib/pages/users_page.dart` | 新建（增强用户管理） | ✅段4 |
| `admin_v2/lib/pages/admins_page.dart` | 新建（管理员账号管理） | ✅段5 ✅ |
| `admin_v2/lib/pages/announcements_page.dart` | 新建（站内公告） | ✅段6 ✅ |
| `admin_v2/lib/pages/stations_page.dart` | 新建（电站总览） | ✅段7 |

### Flutter App（App端公告展示）✅
| 文件 | 操作 |
|---|---|
| `app_v2/lib/home.dart` | 修改：添加滚动公告栏 + 详情弹窗 | ✅段8 |
| `app_v2/lib/services/api_client.dart` | 修改：添加 `getLatestAnnouncements` | ✅段8 |
